module Browsery
  module Utils
    module OverlayAndWidgetHelper
      # Create widgets of type `name` from `items`, where `name` is the widget
      # class name, and `items` is a single or an array of WebDriver elements.
      #
      # @param name [#to_s] the name of the widget, under `browserys/page_objects/widgets`
      #   to load.
      # @param items [Enumerable<Selenium::WebDriver::Element>] WebDriver elements.
      # @return [Enumerable<Browsery::PageObjects::Widgets::Base>]
      # @raise NameError
      def get_widgets!(name, items)
        items = Array(items)
        return [] if items.empty?

        # Load the widget class
        klass_name = "browsery/page_objects/widgets/#{name}".camelize
        klass = begin
          klass_name.constantize
        rescue => exc
          msg = ""
          msg << "Cannot find widget '#{name}', "
          msg << "because could not load class '#{klass_name}' "
          msg << "with underlying error:\n  #{exc.class}: #{exc.message}\n"
          msg << exc.backtrace.map { |str| "    #{str}" }.join("\n")
          raise NameError, msg
        end

        page = self.page_object

        if items.respond_to?(:map)
          items.map { |item| klass.new(page, item) }
        else
          [klass.new(page, items)]
        end
      end

      # Create overlay of type `name`, where `name` is the overlay
      # class name
      #
      # @param name [#to_s] the name of the overlay, under `browserys/page_objects/widgets`
      #   to load.
      # @param items [Enumerable<Selenium::WebDriver::Element>] WebDriver elements.
      # @return [Enumerable<Browsery::PageObjects::Overlay::Base>]
      # @raise NameError
      def get_overlay!(name)
        # Load the Overlay class
        klass_name = "browsery/page_objects/overlay/#{name}".camelize
        klass = begin
          klass_name.constantize
        rescue => exc
          msg = ""
          msg << "Cannot find overlay '#{name}', "
          msg << "because could not load class '#{klass_name}' "
          msg << "with underlying error:\n  #{exc.class}: #{exc.message}\n"
          msg << exc.backtrace.map { |str| "    #{str}" }.join("\n")
          raise NameError, msg
        end
        page = self.page_object
        instance = klass.new(page)
        # Overlay is triggered to show when there's certain interaction on the page
        # So validate! is necessary for loading some elements on some overlays
        begin
          instance.validate!
        rescue Minitest::Assertion => exc
          raise Browsery::PageObjects::InvalidePageState, "#{klass}: #{exc.message}"
        end
        instance
      end


      def page_object
        raise NotImplementedError, "classes including OverlayAndWidgetHelper must override :page_object"
      end

    end #OverlayAndWidgetHelper
  end #Utils
end #Browsery
