require "swank/decorators/decorator_base"

module Swank
  module Decorators
    # Simple decorator that takes variables when declared
    class DecoratorWithContext < DecoratorBase
      # Create a custom null object that can be overriden by defaults
      NOTHING = Object.new

      class << self
        def setup(decorator_name, wrap_block)
          super

          class_eval <<~RUBY, __FILE__, __LINE__ + 1
            def initalize(#{initialize_parameter_string})
            #{initialize_variable_set_string}
            end
          RUBY
        end

        # String representation of of {DecoratorWithContext::NOTHING}.
        #
        # Used by {.initialize_parameter_string}
        NOTHING_STRING = "::Swank::Decorators::DecoratorWithContext::NOTHING"

        # @api private
        def initialize_parameter_string
          wrap_block.parameters.map do |param_type, param_name|
            case param_type
            when :req then param_name
            when :opt then "#{param_name} = #{NOTHING_STRING}"
            when :keyreq then "#{param_name}:"
            when :key then "#{param_name}: #{NOTHING_STRING}"
            when :block then "&#{param_name}"
            when :rest
              (param_name == :*) ? "*" : "*#{param_name}"
            when :keyrest
              (param_name == :**) ? "**" : "**#{param_name}"
            else
              raise ArgumentError, "Bad param_type for #{param_name} - #{param_type}"
            end
          end.join(", ")
        end

        def initialize_variable_set_string
          args = [] # : Array[String]
          kwargs = [] # : Array[String]
          block = "nil"

          wrap_block.parameters.each do |param_type, param_name|
            case param_type
            when :req, :opt
              unless param_name.nil?
                args << param_name # @type var param_name: ::String
              end
            when :keyreq, :key then kwargs << "#{param_name}: #{param_name}"
            when :block then block = param_name
            when :rest
              arg_name = (param_name == :*) ? "*" : "*#{param_name}"
              args << arg_name
            when :keyrest
              arg_name = (param_name == :**) ? "**" : "**#{param_name}"
              kwargs << arg_name
            else
              raise ArgumentError, "Bad param_type for #{param_name} - #{param_type}"
            end
          end

          [
            "  @args = [#{args.join(", ")}]",
            "  @kwargs = {#{kwargs.join(", ")}}",
            "  @block = #{block}",
            "  @args.reject! { |v| v.equal? #{NOTHING_STRING} }",
            "  @kwargs.delete_if { |_, v| v.equal? #{NOTHING_STRING} }"
          ].join("\n")
        end
      end

      # List of positional arguments given
      # @return [Array]
      attr_reader :args

      # List of keyword arguments given
      # @return [Hash]
      attr_reader :kwargs

      # The block argument, if given
      # @return [Proc, nil]
      attr_reader :block

      def initialize(*args, **kwargs, &block)
        @args = args
        @kwargs = kwargs
        @block = block
      end

      def wrap_block
        self.class.wrap_block.call(*args, **kwargs, &block)
      end
    end
  end
end
