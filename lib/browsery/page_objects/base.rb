require 'minitest/assertions'

module Browsery
  module PageObjects

    # The base page object. All page objects should be a subclass of this.
    # Every subclass must implement the following class methods:
    #
    #   expected_path
    #
    # All methods added here will be available to all subclasses, so do so
    # sparingly.  This class has access to assertions, which should only be
    # used to validate the page.
    class Base
      include Minitest::Assertions
      include Utils::Castable
      include Utils::Loggable
      include Utils::PageObjectHelper
      include Utils::OverlayAndWidgetHelper
      extend ElementContainer

      attr_accessor :assertions
      attr_accessor :failures
      attr_reader :driver

      # Given a set of arguments (no arguments by default), return the expected
      # path to the page, which must only have file path and query-string.
      #
      # @param args [String] one or more arguments to be used in calculating
      #   the expected path, if any.
      # @return [String] the expected path.
      def self.expected_path(*args)
        raise NotImplementedError, "expected_path is not defined for #{self}"
      end

      # Initializes a new page object from the driver. When a page is initialized,
      # no validation occurs. As such, do not call this method directly. Rather,
      # use PageObjectHelper#page in a test case, or #cast in another page object.
      #
      # @param driver [Selenium::WebDriver] The WebDriver instance.
      def initialize(driver)
        @driver = driver

        @assertions = 0
        @failures   = []
      end

      def find_first(how, what)
        driver.find_element(how, what)
      end

      def find_all(how, what)
        driver.all(how, what)
      end

      # Returns the current path loaded in the driver.
      #
      # @return [String] The current path, without hostname.
      def current_path
        current_url.path
      end

      # Returns the current URL loaded in the driver.
      #
      # @return [String] The current URL, including hostname.
      def current_url
        URI.parse(driver.current_url)
      end

      ## interface for Overlay And Widget Helper version of get_widgets! and get_overlay!
      def page_object
        self
      end

      # Instructs the driver to visit the {expected_path}.
      #
      # @param args [*Object] optional parameters to pass into {expected_path}.
      def go!(*args)
        driver.get(driver.url_for(self.class.expected_path(*args)))
      end

      # Check that the page includes a certain string.
      #
      # @param value [String] the string to search
      # @return [Boolean]
      def include?(value)
        driver.page_source.include?(value)
      end

      # Retrieves all META tags with a `name` attribute on the current page.
      def meta
        tags = driver.all(:css, 'meta[name]')
        tags.inject(Hash.new) do |vals, tag|
          vals[tag.attribute(:name)] = tag.attribute(:content) if tag.attribute(:name)
          vals
        end
      end

      def headline
        driver.find_element(:css, 'body div.site-content h1').text
      end

      # Get page title from any page
      def title
        driver.title
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

      # Wrap blocks acting on Selenium elements and catch errors they
      # raise. This probably qualifies as a Dumb LISPer Trick. If there's a
      # better Ruby-ish way to do this, I welcome it. [~jacord]
      def with_rescue(lbl, &blk)
        yield ## run the block
        ## rescue errors. Rerunning may help, but we can also test for specific
        ## problems.
      rescue Selenium::WebDriver::Error::ElementNotVisibleError => e
        ## The element is in the DOM but e.visible? is 'false'. Retry may help.
        logger.debug "Retrying #{lbl}: #{e.class}"
        yield
      rescue Selenium::WebDriver::Error::StaleElementReferenceError => e
        ## The page has changed and invalidated your element. Retry may help.
        logger.debug "Retrying #{lbl}: #{e.class}"
        yield
      rescue Selenium::WebDriver::Error::NoSuchElementError => e
        ## Raised by get_element(s). Retry MAY help, but check first for HTTP
        ## 500, which may be best handled higher up the stack.
        logger.debug "Recovering from NoSuchElementError during #{lbl}"
        raise_on_error_page
        ## If we got past the above, retry the block.
        logger.debug "Retrying #{lbl}: #{e.class}"
        yield
      end

      ## Wrap an action, wait for page title change. This function eliminates
      ## some error-prone boilerplate around fetching page titles
      def with_page_title_wait(&blk)
        title = driver.title
        yield
        wait_for_title_change(title)
      end

      # returns the all the page source of a page, useful for debugging
      #
      def page_source
        driver.page_source
      end

      ## PageObject validate! helper. Raises RuntimeError if one of our error
      ## pages is displaying. This can prevent a test from taking the entire
      ## implicit_wait before announcing error. [~jacord]
      def raise_on_error_page
        logger.debug "raise_on_error_page"
        title = ''
        begin
          title = driver.title
        rescue ReadTimeout
          logger.debug 'ReadTimeout exception was thrown while trying to execute driver.title'
          logger.debug 'ignore exception and proceed'
        end
        title = driver.title
        logger.debug "Page Title: '#{title}'"
        raise "HTTP 500 Error" if %r/Internal Server Error/ =~ title
        raise "HTTP 503 Error" if %r/503 Service Temporarily Unavailable/ =~ title
        raise "HTTP 404 Error" if %r/Error 404: Page Not Found/ =~ title

        header = driver.find_element('body h1') rescue nil

        unless header.nil?
          raise "HTTP 500 Error" if header.text == 'Internal Server Error'
        end

      end

      # click on a link on any page, cast a new page and return it
      def click_on_link!(link_text, page_name)
        driver.find_element(:link, link_text).location_once_scrolled_into_view
        driver.find_element(:link, link_text).click
        # check user angent, if it's on IE, wait 2sec for the title change
        sleep 2 if driver.browser == :ie # todo remove this if every page has wait for title change in validate!
        #sleep 5 #wait for 5 secs
        logger.debug "click_on_link '#{link_text}'"
        cast(page_name)
      end

      def wait_for_title_change(title)
        title = driver.title if title.nil?
        logger.debug("Waiting for title change from '#{title}'")
        wait(timeout: 15, message: "Waited 15 sec for page transition")
          .until { driver.title != title }
        logger.debug("Arrived at #{driver.title}")
      end

      def wait_for_link(link_text)
        message = "waited 15 sec, can't find link #{link_text} on page"
        wait(timeout: 15, message: message).until{ driver.find_element(:link, link_text) }

        unless driver.find_element(:link, link_text).displayed?
          driver.navigate.refresh
        end
      end

      # example usage:
      # original_url = driver.current_url
      # driver.find_element(*LINK_REGISTER).click # do some action that should cause url to change
      # wait_for_url_change(original_url)
      def wait_for_url_change(original_url)
        time = 15
        message = "waited #{time} sec, url is still #{original_url}, was expecting it to change"
        wait(timeout: time, message: message).until { driver.current_url != original_url }
      end

      def go_to_page!(url, page_type = :base)
        driver.navigate.to(url)
        cast(page_type)
      end

      def go_to_subpage!(url_path, page_type = :base)
        driver.navigate.to(driver.url_for(url_path))
        cast(page_type)
      end

    end
  end
end
