module Browsery

  # An Browsery-specific test case container, which extends the default ones,
  # adds convenience helper methods, and manages page objects automatically.
  class TestCase < Minitest::Test
    @@selected_methods = []
    @@runnables_count = 0
    @@regression_suite = Array.new
    @@serials = Array.new
    @@test_suite_data = if File.exist?(Browsery.root.join("config/browsery/test_suite.yml"))
                          YAML.load_file(Browsery.root.join("config/browsery/test_suite.yml"))
                        else
                          default = {"regression"=>{"tag_to_exclude"=>:non_regression}}
                          if Browsery.root != Browsery.gem_root
                            # Only necessary to notify gem user, not gem developer
                            puts "config/browsery/test_suite.yml doesn't exist, using default:\n#{default}"
                            puts "It's recommended to have this config file as it'll avoid problem when using tapout"
                          end
                          default
                        end

    # Standard exception class that signals that the test with that name has
    # already been defined.
    class TestAlreadyDefined < ::StandardError; end

    # Include helper modules
    include Browsery::Utils::AssertionHelper
    include Browsery::Utils::DataGeneratorHelper
    include Browsery::Utils::Loggable
    include Browsery::Utils::PageObjectHelper

    class <<self

      # @!attribute [rw] options
      #   @return [Hash] test case options
      attr_accessor :options

      # Explicitly remove _all_ tests from the current class. This will also
      # remove inherited test cases.
      #
      # @return [TestCase] self
      def remove_tests
        klass = class <<self; self; end
        public_instance_methods.grep(/^test_/).each do |method|
          klass.send(:undef_method, method.to_sym)
        end
        self
      end

      # Call this at the top of your test case class in order to run all tests
      # in alphabetical order
      #
      # @return [TestCase] self
      # @example
      #   class SomeName < TestCase
      #     run_in_order!
      #
      #     test :feature_search_01 { ... }
      #     test :feature_search_02 { ... }
      #   end
      def run_in_order!
        # `self` is the class, so we want to reopen the metaclass instead, and
        # redefine the methods there
        class <<self
          undef_method :test_order if method_defined? :test_order
          define_method :test_order do
            :alpha
          end
        end

        # Be nice and return the class back
        self
      end

      # Filter out anything not matching our tag selection, if any.
      #
      # If it's parallel run,
      # only add filtered methods from each runnable to a list of to run methods,
      # instead of running them one by one right away,
      # and finally when all runnable methods are traversed, call parallel to run that list of methods.
      #
      # @return [Enumerable<Symbol>] the methods marked runnable
      def runnable_methods
        methods  = super
        selected = Browsery.settings.tags

        filtered_methods = filter_methods(methods, selected)

        if Browsery.settings.parallel
          unless filtered_methods.empty?
            if selected.nil? || selected.empty?
              @@selected_methods = @@regression_suite
            else
              methods_to_add = filtered_methods.map { |method| method.to_sym if @@regression_suite.include?(method.to_sym) }
              @@selected_methods += methods_to_add
            end
          end

          @@runnables_count += 1
          browsery_runnables = Minitest::Runnable.runnables - [Minitest::Test, Minitest::Unit::TestCase]

          if @@runnables_count == browsery_runnables.size
            parallel = Parallel.new(Browsery.settings.parallel, @@selected_methods)
            parallel.clean_result!
            parallel.run_in_parallel!
            parallel.remove_redundant_tap if Browsery.settings.rerun_failure
            parallel.aggregate_tap_results
            exit
          end

          return [] # no test will run
        else
          filtered_methods
        end
      end

      # Filter methods in a runnable based on our tag selection
      def filter_methods(methods, selected)
        # If no tags are selected, run all tests
        if selected.nil? || selected.empty?
          return methods
        end

        selected_methods = methods.select do |method|
          # If the method's tags match any of the tag sets, allow it to run
          selected.any? do |tag_set|
            # Retrieve the tags for that method
            method_options = self.options[method.to_sym] rescue nil
            tags           = method_options[:tags]       rescue nil

            # If the method's tags match ALL of the tags in the tag set, allow
            # it to run; in the event of a problem, allow the test to run
            tag_set.all? do |tag|
              if tag =~ %r/^!/
                !tags.include?(tag[%r/^!(.*)/,1].to_sym) || nil
              else
                tags.include?(tag.to_sym) || nil
              end rescue true
            end
          end
        end

        selected_methods
      end

      # Install a setup method that runs before every test.
      #
      # @return [void]
      def setup(&block)
        define_method(:setup) do
          super()
          instance_eval(&block)
        end
      end

      # Install a teardown method that runs after every test.
      #
      # @return [void]
      def teardown(&block)
        define_method(:teardown) do
          super()
          instance_eval(&block)
        end
      end

      # Defines a test case.
      #
      # It can take the following options:
      #
      # * `tags`: An array of any number of tags associated with the test case.
      #          When not specified, the test will always be run even when only
      #          certain tags are run. When specified but an empty array, the
      #          test will only be run if all tags are set to run. When the array
      #          contains one or more tags, then the test will only be run if at
      #          least one tag matches.
      # * `serial`: An arbitrary string that is used to refer to all a specific
      #            test case. For example, this can be used to store the serial
      #            number for the test case.
      #
      # @param name [String, Symbol] an arbitrary but unique name for the test,
      #   preferably unique across all test classes, but not required
      # @param opts [Hash]
      # @param block [Proc] the testing logic
      # @return [void]
      def test(name, **opts, &block)
        # Ensure that the test isn't already defined to prevent tests from being
        # swallowed silently
        method_name = test_name(name)
        check_not_defined!(method_name)

        # Add an additional tag, which is unique for each test class, to all tests
        # To allow user to run tests with option '-t class_name_of_the_test' without
        # duplicate run for all tests in NameOfTheTest. The namespace of the class
        # is ignored here.
        opts[:tags] << ('class_'+ self.name.demodulize.underscore).to_sym

        # Flunk unless a logic block was provided
        if block_given?
          self.options ||= {}
          self.options[method_name.to_sym] = opts.deep_symbolize_keys
          define_method(method_name, &block)
        else
          flunk "No implementation was provided for test '#{method_name}' in #{self}"
        end

        # add all tests to @@regression_suite
        # excluding the ones with tags in tags_to_exclude defined in config
        unless exclude_by_tag?('regression', opts[:tags])
          @@regression_suite << method_name
          @@serials << opts[:serial]
        end
      end

      # @param suite [String] type of test suite
      # @param tags [Array] an array of tags a test has
      # @return [Boolean]
      def exclude_by_tag?(suite, tags)
        tag_to_exclude = @@test_suite_data[suite]['tag_to_exclude']
        if tags.include? tag_to_exclude
          true
        else
          false
        end
      end

      # Check that +method_name+ hasn't already been defined as an instance
      # method in the current class, or in any superclasses.
      #
      # @param method_name [Symbol] the method name to check
      # @return [void]
      protected
      def check_not_defined!(method_name)
        already_defined = instance_method(method_name) rescue false
        raise TestAlreadyDefined, "Test #{method_name} already exists in #{self}" if already_defined
      end

      # Transform the test +name+ into a snake-case name, prefixed with "test_".
      #
      # @param name [#to_s] the test name
      # @return [Symbol] the transformed test name symbol
      # @example
      #   test_name(:search_zip) # => :test_search_zip
      private
      def test_name(name)
        undercased_name = sanitize_name(name).gsub(/\s+/, '_')
        "test_#{undercased_name}".to_sym
      end

      # Sanitize the +name+ by removing consecutive non-word characters into a
      # single whitespace.
      #
      # @param name [#to_s] the name to sanitize
      # @return [String] the sanitized value
      # @example
      #   sanitize_name('The Best  Thing [#5]') # => 'The Best Thing 5'
      #   sanitize_name(:ReallySuper___awesome) # => 'ReallySuper Awesome'
      private
      def sanitize_name(name)
        name.to_s.gsub(/\W+/, ' ').strip
      end

    end

  end

end
