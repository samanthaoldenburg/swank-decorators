module Swank
  module Decorators
    # The `func` referenced when defining decorators.
    #
    # A special proc that retains useful context for decorators.
    class DecoratorExecutionChain < Proc
      # The name of the method we are currently applying decorators to
      #
      # @return [Symbol]
      def method_name
        binding.local_variable_get(:method_name)
      end
    end
  end
end
