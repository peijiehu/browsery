require 'minitest/assertions'

module Browsery
  module Utils

    # A collection of custom, but frequently-used assertions.
    module AssertionHelper

      # Assert that an element, specified by `how` and `what`, are absent from
      # the current page's context.
      #
      # @param how [:class, :class_name, :css, :id, :link_text, :link,
      #   :partial_link_text, :name, :tag_name, :xpath]
      # @param what [String, Symbol]
      def assert_element_absent(how, what)
        assert_raises Selenium::WebDriver::Error::NoSuchElementError do
          @driver.find_element(how, what)
        end
      end

      # Assert that an element, specified by `how` and `what`, are present from
      # the current page's context.
      #
      # @param how [:class, :class_name, :css, :id, :link_text, :link,
      #   :partial_link_text, :name, :tag_name, :xpath]
      # @param what [String, Symbol]
      def assert_element_present(how, what)
        @driver.find_element(how, what)
      end

    end

  end
end

