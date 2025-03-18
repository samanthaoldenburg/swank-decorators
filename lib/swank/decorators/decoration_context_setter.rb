# lib/decoration_context_setter.rb

module Swank
  module Decorators
    module DecorationContextSetter
      SETTER_FILE = __FILE__
      SETTER_LINE = __LINE__ + 1
      SETTER_SOURCE_FORMAT = <<~RUBY
        def %<method_name>s(...)
          decoration_context = class_variable_get(
            :@@swank_decoration_contexts
          )[:%<method_name>s][:%<mode>s]

          super(decoration_context, ...)
        end
      RUBY

      def create_context_setter!(method_name, mode)
        class_eval(
          format(SETTER_SOURCE_FORMAT, method_name: method_name, mode: mode),
          SETTER_FILE,
          SETTER_LINE
        )
      end
    end
  end
end
