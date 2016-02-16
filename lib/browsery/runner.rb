module Browsery
  class Runner

    attr_accessor :options
    @after_hooks = []
    @@rerun_count = 0

    def self.after_run(&blk)
      @after_hooks << blk
    end

    def self.run!(args)
      exit_code = self.run(args)
      @after_hooks.reverse_each(&:call)
      Kernel.exit(exit_code || false)
    end

    def self.run args = []
      Minitest.load_plugins

      @options = Minitest.process_args args

      self.before_run

      reporter = self.single_run

      rerun_failure = @options[:rerun_failure]
      if rerun_failure && !reporter.passed?
        while @@rerun_count < rerun_failure && !reporter.passed?
          reporter = self.single_run
          @@rerun_count += 1
        end
      end

      reporter.passed?
    end

    # Inialize a new reporter, run test
    # Return reporter, which carrys test result
    def self.single_run
      reporter = Minitest::CompositeReporter.new
      reporter << Minitest::SummaryReporter.new(@options[:io], @options)
      reporter << Minitest::ProgressReporter.new(@options[:io], @options)

      Minitest.reporter = reporter # this makes it available to plugins
      Minitest.init_plugins @options
      Minitest.reporter = nil # runnables shouldn't depend on the reporter, ever

      reporter.start
      Minitest.__run reporter, @options
      Minitest.parallel_executor.shutdown
      reporter.report

      reporter
    end

    # before hook where you have parsed @options when loading tests
    def self.before_run
      tests_yml_full_path = Browsery.root.join('config/browsery', 'tests.yml').to_s
      if File.exist? tests_yml_full_path
        self.load_tests(tests_yml_full_path)
      else
        puts "Config file #{tests_yml_full_path} doesn't exist"
        puts "browsery doesn't know where your tests are located and how they are structured"
      end
    end

    # only load tests you need by specifying env option in command line
    def self.load_tests(tests_yml_full_path)
      tests_yml = YAML.load_file tests_yml_full_path

      self.check_config(tests_yml)

      tests_dir_relative_path = tests_yml['tests_dir']['relative_path']
      multi_host_flag = tests_yml['tests_dir']['multi-host']
      default_host = tests_yml['tests_dir']['default_host']
      host = @options[:env].split(/_/)[0] rescue default_host

      self.configure_load_path(tests_dir_relative_path)

      # load page_objects.rb first
      Dir.glob("#{tests_dir_relative_path}/#{multi_host_flag ? host+'/' : ''}*.rb") do |f|
        f.sub!(/^#{tests_dir_relative_path}\//, '')
        require f
      end

      # files under subdirectories shouldn't be loaded, eg. archive/
      Dir.glob("#{tests_dir_relative_path}/#{multi_host_flag ? host+'/' : ''}test_cases/*.rb") do |f|
        f.sub!(/^#{tests_dir_relative_path}\//, '')
        require f
      end
    end

    def self.check_config(tests_yml)
      raise "relative_path must be provided in #{tests_yml}" unless tests_yml['tests_dir']['relative_path'].is_a? String
      raise "multi-host must be provided in #{tests_yml}" unless [true, false].include?(tests_yml['tests_dir']['multi-host'])
      raise "default_host must be provided in #{tests_yml}" unless tests_yml['tests_dir']['default_host'].is_a? String
    end

    def self.configure_load_path(tests_dir_relative_path)
      tests_dir_full_path = Browsery.root.join(tests_dir_relative_path).to_s
      if Dir.exist? tests_dir_full_path
        $LOAD_PATH << tests_dir_full_path
      else
        puts "Tests directory #{tests_dir_full_path} doesn't exist"
        puts "No test will run."
      end
    end

  end
end
