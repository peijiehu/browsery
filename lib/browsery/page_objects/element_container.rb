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

      def section(section_name, *args)
        section_class, find_args = extract_section_options args
        build section_name, *find_args do |how, what|
          define_method section_name do
            section_class.new self, find_first(how, what)
          end
        end
      end

      def sections(section_collection_name, *args)
        section_class, find_args = extract_section_options args
        build section_collection_name, *find_args do
          define_method section_collection_name do
            self.class.raise_if_block(self, section_collection_name.to_s, !element_block.nil?)
            find_all(how, what).map do |element|
              section_class.new self, element
            end
          end
        end
      end

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

      def extract_section_options(args, &block)
        case
        when args.first.is_a?(Class)
          section_class = args.shift
        when block_given?
          section_class = Class.new Browsery::PageObjects::Section, &block
        else
          raise ArgumentError, 'You should provide section class either as a block, or as the second argument'
        end
        return section_class, args
      end

    end
  end
end
