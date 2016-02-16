module Browsery
  module PageObjects
    module Overlay

      # A Overlay represents a portion (an element) of a page that is repeated
      # or reproduced multiple times, either on the same page, or across multiple
      # page objects or page modules.
      class Base
        include Utils::Castable
        include Utils::PageObjectHelper
        include Utils::OverlayAndWidgetHelper
        extend ElementContainer

        attr_reader :driver

        def initialize(page)
          @driver = page.driver
          @page = page

          # works here but not in initialize of base of page objects
          # because a page instance is already present when opening an overlay
        end

        ## for overlay that include Utils::OverlayAndWidgetHelper
        def page_object
          @page
        end

        def find_first(how, what)
          driver.find_element(how, what)
        end

        def find_all(how, what)
          driver.all(how, what)
        end

        # By default, any driver state is accepted for any page. This method
        # should be overridden in subclasses.
        def validate!
          true
        end

        # Wait for all dom events to load
        def wait_for_dom(timeout = 15)
          uuid = SecureRandom.uuid
          # make sure body is loaded before appending anything to it
          wait(timeout: timeout, msg: "Timeout after waiting #{timeout} for body to load").until do
            is_element_present?(:css, 'body')
          end
          driver.execute_script <<-EOS
            _.defer(function() {
            $('body').append("<div id='#{uuid}'></div>");
            });
          EOS
          wait(timeout: timeout, msg: "Timeout after waiting #{timeout} for all dom events to finish").until do
            is_element_present?(:css, "div[id='#{uuid}']")
          end
        end

        # Wait on all AJAX requests to finish
        def wait_for_ajax(timeout = 15)
          wait(timeout: timeout, msg: "Timeout after waiting #{timeout} for all ajax requests to finish").until do
            driver.execute_script 'return window.jQuery != undefined && jQuery.active == 0'
          end
        end

        # Explicitly wait for a certain condition to be true:
        #   wait.until { driver.find_element(:css, 'body.tmpl-srp') }
        # when timeout is not specified, default timeout 5 sec will be used
        # when timeout is larger than 15, max timeout 15 sec will be used
        def wait(opts = {})
          if !opts[:timeout].nil? && opts[:timeout] > 15
            puts "WARNING: #{opts[:timeout]} sec timeout is NOT supported by wait method,
                max timeout 15 sec will be used instead"
            opts[:timeout] = 15
          end
          Selenium::WebDriver::Wait.new(opts)
        end

      end

    end
  end
end

