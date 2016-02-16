module Browsery
  module PageObjects
    module ElementContainer

      def element(element_name, *find_args)
        build element_name, *find_args do |how, what|
          define_method element_name.to_s do
            find_first(how, what)
          end
        end
      end

      def elements(collection_name, *find_args)
        build collection_name, *find_args do |how, what|
          define_method collection_name.to_s do
            find_all(how, what)
          end
        end
      end
      alias_method :collection, :elements

      def add_to_mapped_items(item)
        @mapped_items ||= []
        @mapped_items << item.to_s
      end

      private

      def build(name, *find_args)
        if find_args.empty?
          create_no_selector name
        else
          add_to_mapped_items name
          if find_args.size == 1
            yield(:css, *find_args)
          else
            yield(*find_args)
          end
        end
      end

      def create_no_selector(method_name)
        define_method method_name do
          fail Browsery::NoSelectorForElement.new, "#{self.class.name} => :#{method_name} needs a selector"
        end
      end

    end
  end
end