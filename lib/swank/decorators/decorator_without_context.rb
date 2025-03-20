require "swank/decorators/decorator_base"

module Swank
  module Decorators
    # A simple decorator that can be invoked without variables
    class DecoratorWithoutContext < DecoratorBase
      def wrap_block
        self.class.wrap_block
      end
    end
  end
end
