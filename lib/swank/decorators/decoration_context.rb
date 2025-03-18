require "ostruct"

module Swank
  module Decorators
    # Data structure to store information used by the decoration wrapping method
    #
    class DecorationContext < OpenStruct
      # The name of the method we are currently wrapping
      #
      # We implement this by hand, despite the `OpenStruct` inheritance, so we
      # can stop others from setting this field.
      #
      # @return [Symbol]
      attr_reader :method_name

      def set_method_name(method_name)
        @method_name = method_name
      end

      # Manually adding `method_name` to your context is not allowed.
      #
      # It's automatically added when we inject the decoration into the method.
      def method_name=(method_name)
        raise NotImplementedError
      end
    end
  end
end
