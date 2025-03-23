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
              (param_name.to_sym == :*) ? "*" : "*#{param_name}"
            when :keyrest
              (param_name.to_sym == :**) ? "**" : "**#{param_name}"
            else
              raise ArgumentError, "Bad param_type for #{param_name} - #{param_type}"
            end
          end.join(", ")
        end

        def initialize_variable_set_string
          variables = {args: [], kwargs: [], block: "nil"}
          wrap_block.parameters.each do |param_type, param_name|
            case param_type
            when :req, :opt then variables[:args] << param_name
            when :keyreq, :key then variables[:kwargs] << "#{param_name}: #{param_name}"
            when :block then variables[:block] = param_name
            when :rest
              if param_name.to_sym == :*
                variables[:kwargs] << "*"
              else
                variables[:kwargs] << "*#{param_name}"
              end
            when :keyrest
              if param_name.to_sym == :**
                variables[:kwargs] << "*"
              else
                variables[:kwargs] << "**#{param_name}"
              end
            else
              raise ArgumentError, "Bad param_type for #{param_name} - #{param_type}"
            end
          end

          [
            "  @args = [#{variables[:args].join(", ")}]",
            "  @kwargs = {#{variables[:kwargs].join(", ")}}",
            "  @block = #{variables[:block]}",
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
