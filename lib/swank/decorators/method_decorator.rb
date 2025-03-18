# @see sample.rb
module Swank
  module Decorators
    module MethodDecorator
      # @!group DSL
      #

      def decorator_name(name = nil)
        if name.nil?
          @decorator_name ||= name.split("::")
        else
          @decorator_name = name
        end
      end

      def wrap(&block)
        @wrap_block = block
      end

      def wrap_block
        @wrap_block
      end

      #
      # @!endgroup DSL

      # @api private
      def bind_to_object!(obj)
        decoration_injector = Swank::Decorators::DecorationInjector.bind(obj)
        decoration_injector.register_decorator! self

        obj.singleton_class.class_eval <<~RUBY, __FILE__, __LINE__ + 1
          def #{decorator_name}!(**context)
            class_variable_get(:@@swank_decoration_injector).queue_decoration(
              :#{decorator_name},
              ::Swank::Decorators::DecorationContext.new(context)
            )
          end
        RUBY
      end
    end
  end
end
