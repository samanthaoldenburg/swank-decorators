module Swank
  module Decorators
    # Abstract class for actual decorations
    # @abstract
    class DecoratorBase
      class << self
        # Setup a decorator, defining its name an implemenation
        def setup(decorator_name, wrap_block)
          @decorator_name = decorator_name
          @wrap_block = wrap_block
        end

        # Name of the decorator
        # @return [Symbol]
        attr_reader :decorator_name

        # Implementation of the decorator
        # @return [Proc]
        attr_reader :wrap_block
      end

      # (see .decorator_name)
      def decorator_name
        self.class.decorator_name
      end

      # @return [Proc]
      # @abstract
      def wrap_block
        raise NotImplementedError
      end

      # @return [DecoratorBase]
      attr_reader :nested

      def initialize(*)
        # Do nothing
      end

      def add_to_chain!(decorator)
        @nested ? nested.add_to_chain!(decorator) : @nested = decorator
      end

      def final?
        !nested
      end
    end
  end
end
