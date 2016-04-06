module Browsery
  module PageObjects
    class Section
      extend ElementContainer
      include Utils::Castable
      include Utils::Loggable
      include Utils::PageObjectHelper

      attr_reader :root_element, :parent

      def initialize(parent, root_element)
        @parent = parent
        @root_element = root_element
        # Browsery.within(@root_element) { yield(self) } if block_given?
      end

      def parent_page
        candidate_page = parent
        until candidate_page.is_a?(Browsery::PageObjects::Base)
          candidate_page = candidate_page.parent
        end
        candidate_page
      end

      def find_first(how, what)
        root_element.find_element(how, what)
      end

      def find_all(how, what)
        root_element.all(how, what)
      end

    end
  end
end
