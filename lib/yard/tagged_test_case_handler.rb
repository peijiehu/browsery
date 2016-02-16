
module YARD

  # Intercept all tagged test case definitions in order to document test case
  # taggings automatically.
  class TaggedTestCaseHandler < YARD::Handlers::Ruby::Base
    # Register ourselves to handle method calls to `test`. Limit our interactions
    # to the current namespace only.
    handles method_call(:test)
    namespace_only

    # Process the method call to `test do ... end` as a dynamic method definition.
    def process
      # Retrieve the currently-active statement and its parameters
      stmt   = self.statement
      params = stmt.parameters

      # Move the AST pointer to the first parameter that is either a string or
      # an identifier (e.g., inner symbol)
      name = params.first.jump(:tstring_content, :ident).source

      # Create a new method object in the namespace with the correct name
      object = YARD::CodeObjects::MethodObject.new(self.namespace, "test_#{name}")

      # Parse the block between the `test do` and `end` and attribute it to the
      # method object above
      self.parse_block(stmt.last.last, owner: object)

      # Annotate it as a dynamic object with custom attributes
      object.dynamic = true

      # The options s-exp looks like:
      #
      #   s(s(:assoc, s(:label, 'Key1'), s(...)),
      #     s(:assoc, s(:label, 'Key2'), s(...))
      #   )
      #
      # if one exists (nil otherwise)
      if opts_sexp = params[1]
        object['test_case_attrs'] = opts_sexp.inject(Hash.new) do |hsh, kv|
          key_sexp, value_sexp = kv.jump(:assoc)

          if (string_sexp = value_sexp.jump(:tstring_content)) && (string_sexp.type == :tstring_content)
            hsh[key_sexp.first] = string_sexp.first
          elsif (array_sexp = value_sexp.jump(:array)) && (array_sexp.type == :array)
            hsh[key_sexp.first] = array_sexp.first.map { |sexp| sexp.jump(:tstring_content, :ident).first }
          else
            raise ArgumentError, "Cannot parse and render: #{kv.inspect}"
          end

          hsh
        end
      end

      # Register the object
      self.register(object)
    end

  end

end
