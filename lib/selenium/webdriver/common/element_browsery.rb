require 'selenium-webdriver'

module Selenium
  module WebDriver

    class Element

      # Click in a way that is reliable for IE and works for other browsers as well
      def browser_safe_click
        bridge.browser == :internet_explorer ? send_keys(:enter) : click
      end

      # Click in a way that is reliable for IE and Firefox and works for other browsers as well
      def browser_safe_checkbox_click
        (bridge.browser == :internet_explorer || bridge.browser == :firefox) ? send_keys(:space) : click
      end

    end

  end
end
