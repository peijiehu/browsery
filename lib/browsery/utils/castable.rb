
module Browsery
  module Utils

    module Castable

      module ClassMethods

        # Attempts to create a new page object from a driver state. Use the
        # instance method for convenience. Raises `NameError` if the page could
        # not be found.
        #
        # @param driver [Selenium::WebDriver] The instance of the current
        #   WebDriver.
        # @param name [#to_s] The name of the page object to instantiate.
        # @return [Base] A subclass of `Base` representing the page object.
        # @raise InvalidPageState if the page cannot be casted to
        # @raise NameError if the page object doesn't exist
        def cast(driver, name)
          # Transform the name string into a file path and then into a module name
          klass_name = "browsery/page_objects/#{name}".camelize

          # Attempt to load the class
          klass = begin
            klass_name.constantize
          rescue => exc
            msg = ""
            msg << "Cannot find page object '#{name}', "
            msg << "because could not load class '#{klass_name}' "
            msg << "with underlying error:\n  #{exc.class}: #{exc.message}\n"
            msg << exc.backtrace.map { |str| "    #{str}" }.join("\n")
            raise NameError, msg
          end

          # Instantiate the class, passing the driver automatically, and
          # validates to ensure the driver is in the correct state
          instance = klass.new(driver)
          begin
            instance.validate!
          rescue Minitest::Assertion => exc
            raise Browsery::PageObjects::InvalidePageState, "#{klass}: #{exc.message}"
          end
          instance
        end

      end

      # Extend the base class in which this module is included in order to
      # inject class methods.
      #
      # @param base [Class]
      # @return [void]
      def self.included(base)
        base.extend(ClassMethods)
      end

      # The preferred way to create a new page object from the current page's
      # driver state. Raises a NameError if the page could not be found. If
      # casting causes a StaleElementReferenceError, the method will retry up
      # to 2 more times.
      #
      # @param name [String] see {Base.cast}
      # @return [Base] The casted page object.
      # @raise InvalidPageState if the page cannot be casted to
      # @raise NameError if the page object doesn't exist
      def cast(name)
        tries ||= 3
        self.class.cast(@driver, name).tap do |new_page|
          self.freeze
          Browsery.logger.debug("Casting #{self.class}(##{self.object_id}) into #{new_page.class}(##{new_page.object_id})")
        end
      rescue Selenium::WebDriver::Error::StaleElementReferenceError => sere
        Browsery.logger.debug("#{self.class}(##{@driver.object_id})->cast(#{name}) raised a potentially-swallowed StaleElementReferenceError")
        sleep 1
        retry unless (tries -= 1).zero?
      end

      # Cast the page to any of the listed `names`, in order of specification.
      # Returns the first page that accepts the casting, or returns nil, rather
      # than raising InvalidPageState.
      #
      # @param names [Enumerable<String>] see {Base.cast}
      # @return [Base, nil] the casted page object, if successful; nil otherwise.
      # @raise NameError if the page object doesn't exist
      def cast_any(*names)
        # Try one at a time, swallowing InvalidPageState exceptions
        names.each do |name|
          begin
            return self.cast(name)
          rescue InvalidPageState
            # noop
          end
        end

        # Return nil otherwise
        return nil
      end

    end

  end
end

