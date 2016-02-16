module Browsery
  module Utils

    # Page object-related helper methods.
    module PageObjectHelper

      # Helper method to instantiate a new page object. This method should only
      # be used when first loading; subsequent page objects are automatically
      # instantiated by calling #cast on the page object.
      #
      # Pass optional parameter Driver, which can be initialized in test and will override the global driver here.
      #
      # @param name [String, Driver]
      # @return [PageObject::Base]
      def page(name, override_driver=nil)
        # Get the fully-qualified class name
        klass_name = "browsery/page_objects/#{name}".camelize
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

        # Get a default connector
        @driver = Browsery::Connector.get_default if override_driver.nil?
        @driver = override_driver if !override_driver.nil?
        instance = klass.new(@driver)

        # Set SauceLabs session(job) name to test's name if running on Saucelabs
        begin
          update_sauce_session_name if connector_is_saucelabs? && !@driver.nil?
        rescue
          self.logger.debug "Failed setting saucelabs session name for #{name()}"
        end

        # Before visiting the page, do any pre-processing necessary, if any,
        # but only visit the page if the pre-processing succeeds
        if block_given?
          retval = yield instance
          instance.go! if retval
        else
          instance.go! if override_driver.nil?
        end

        # similar like casting a page, necessary to validate some element on a page
        begin
          instance.validate!
        rescue Minitest::Assertion => exc
          raise Browsery::PageObjects::InvalidePageState, "#{klass}: #{exc.message}"
        end

        # Return the instance as-is
        instance
      end

      # Local teardown for page objects. Any page objects that are loaded will
      # be finalized upon teardown.
      #
      # @return [void]
      def teardown
        if !passed? && !skipped? && !@driver.nil?
          json_save_to_ever_failed if Browsery.settings.rerun_failure
          print_sauce_link if connector_is_saucelabs?
          take_screenshot
        end
        begin
          update_sauce_session_status if connector_is_saucelabs? && !@driver.nil? && !skipped?
        rescue
          self.logger.debug "Failed setting saucelabs session status for #{name()}"
        end

        Browsery::Connector.finalize!
        super
      end

      # Take screenshot and save as png with test name as file name
      def take_screenshot
        @driver.save_screenshot("logs/#{name}.png")
      end

      # Create new/override same file ever_failed_tests.json with fail count
      def json_save_to_ever_failed
        ever_failed_tests = 'logs/tap_results/ever_failed_tests.json'
        data_hash = {}
        if File.file?(ever_failed_tests) && !File.zero?(ever_failed_tests)
          data_hash = JSON.parse(File.read(ever_failed_tests))
        end

        if data_hash[name]
          data_hash[name]["fail_count"] += 1
        else
          data_hash[name] = { "fail_count" => 1 }
        end
        begin
          data_hash[name]["last_fail_on_sauce"] = "saucelabs.com/tests/#{@driver.session_id}"
        rescue
          self.logger.debug "Failed setting last_fail_on_sauce, driver may not be available"
        end

        File.open(ever_failed_tests, 'w+') do |file|
          file.write JSON.pretty_generate(data_hash)
        end
      end

      # Print out a link of a saucelabs's job when a test is not passed
      # Rescue to skip this step for tests like cube tracking
      def print_sauce_link
        begin
          puts "Find test on saucelabs: https://saucelabs.com/tests/#{@driver.session_id}"
        rescue
          puts 'can not retrieve driver session id, no link to saucelabs'
        end
      end

      # Update SauceLabs session(job) name and build number/name
      def update_sauce_session_name
        http_auth = Browsery.settings.sauce_session_http_auth(@driver)
        body = { 'name' => name() }
        unless (build_number = ENV['JENKINS_BUILD_NUMBER']).nil?
          body['build'] = build_number
        end
        RestClient.put(http_auth, body.to_json, {:content_type => "application/json"})
      end

      # Update session(job) status if test is not skipped
      def update_sauce_session_status
        http_auth = Browsery.settings.sauce_session_http_auth(@driver)
        body = { "passed" => passed? }
        RestClient.put(http_auth, body.to_json, {:content_type => "application/json"})
      end

      def connector_is_saucelabs?
        Browsery.settings.connector.include? 'saucelabs'
      end

      # Generic page object helper method to clear and send keys to a web element found by driver
      # @param [Element, String]
      def put_value(web_element, value)
        web_element.clear
        web_element.send_keys(value)
      end

      # Helper method for retrieving value from yml file
      # todo should be moved to FileHelper.rb once we created this file in utils
      # @param [String, String]
      # keys, eg. "timeouts:implicit_wait"
      def read_yml(file_name, keys)
        data = Hash.new
        begin
          data = YAML.load_file "#{file_name}"
        rescue
          raise Exception, "File #{file_name} doesn't exist" unless File.exist?(file_name)
        rescue
          raise YAMLErrors, "Failed to load #{file_name}"
        end
        keys_array = keys.split(/:/)
        value = data
        keys_array.each do |key|
          value = value[key]
        end
        value
      end

      # Retry a block of code for a number of times
      def retry_with_count(count, &block)
        try = 0
        count.times do
          try += 1
          begin
            block.call
            return true
          rescue Exception => e
            Browsery.logger.warn "Exception: #{e}\nfrom\n#{block.source_location.join(':')}"
            Browsery.logger.warn "Retrying" if try < count
          end
        end
      end

      def with_url_change_wait(&block)
        starting_url = @driver.current_url
        block.call
        wait(timeout: 15, message: 'Timeout waiting for URL to change')
          .until { @driver.current_url != starting_url }
      end

      # Check if a web element exists on page or not, without wait
      def is_element_present?(how, what, driver = nil)
        element_appeared?(how, what, driver)
      end

      # Check if a web element exists and displayed on page or not, without wait
      def is_element_present_and_displayed?(how, what, driver = nil)
        element_appeared?(how, what, driver, check_display = true)
      end

      def wait_for_element_to_display(how, what, friendly_name = "element")
          wait(timeout: 15, message: "Timeout waiting for #{friendly_name} to display")
            .until {is_element_present_and_displayed?(how, what)}
      end

      def wait_for_element_to_be_present(how, what, friendly_name = "element")
        wait(timeout: 15, message: "Timeout waiting for #{friendly_name} to be present")
          .until {is_element_present?(how, what)}
      end

      # Useful when you want to wait for the status of an element attribute to change
      # Example: the class attribute of <body> changes to include 'logged-in' when a user signs in to rent.com
      # Example usage: wait_for_attribute_status_change(:css, 'body', 'class', 'logged-in', 'sign in')
      def wait_for_attribute_to_have_value(how, what, attribute, value, friendly_name = "attribute")
        wait(timeout: 15, message: "Timeout waiting for #{friendly_name} status to update")
          .until { driver.find_element(how, what).attribute(attribute).include?(value) rescue retry }
      end

      def current_page(calling_page)
        calling_page.class.to_s.split('::').last.downcase
      end

      private

      # @param  eg. (:css, 'button.cancel') or (*BUTTON_SUBMIT_SEARCH)
      # @param  also has an optional parameter-driver, which can be @element when calling this method in a widget object
      # @return [boolean]
      def element_appeared?(how, what, driver = nil, check_display = false)
        original_timeout = read_yml("config/browsery/connectors/saucelabs.yml", "timeouts:implicit_wait")
        @driver.manage.timeouts.implicit_wait = 0
        result = false
        parent_element = @driver if driver == nil
        parent_element = driver if driver != nil
        elements = parent_element.find_elements(how, what)
        if check_display
          begin
            result = true if elements.size() > 0 && elements[0].displayed?
          rescue
            result = false
          end
        else
          result = true if elements.size() > 0
        end
        @driver.manage.timeouts.implicit_wait = original_timeout
        result
      end

      # Method that overrides click to send the enter key to the element if the current browser
      # is internet explorer. Used when sending the enter key to the element will work
      def browser_safe_click(element)
        driver.browser == :internet_explorer ? element.send_keys(:enter) : element.click
      end

      # Method that overrides click to send the space key to the checkbox if the current browser
      # is internet explorer. Used when sending the space key to the checkbox will work
      def browser_safe_checkbox_click(element)
        (driver.browser == :internet_explorer || driver.browser == :firefox) ? element.send_keys(:space) : element.click
      end

    end

  end
end
