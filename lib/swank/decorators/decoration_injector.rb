# lib/decoration_injector.rb

module Swank
  module Decorators
    class DecorationInjector
      # Module that intercepts method_adds to inject decorators
      module InjectionHook
        # Inject the added method with all queued instance method decorators
        # @param method_name [Symbol]
        # @return [void]
        def method_added(method_name)
          decoration_injector.inject_decorations!(method_name.to_sym, mode: :instance)

          super
        end

        # Inject the added method with all queued singleton method decorators
        # @param method_name [Symbol]
        # @return [void]
        def singleton_method_added(method_name)
          decoration_injector.inject_decorations!(method_name.to_sym, mode: :singleton)

          super
        end

        private

        def decoration_injector
          class_variable_get(:@@swank_decoration_injector)
        end
      end

      # Set up decoration injection for `subject`
      #
      # Does the following.
      #   1. Ensures `subject` has a class-level variable `@@swank_decoration_injector`
      #     a. If not, set it to an instance of {DecorationInjector}
      #   2. Prepend `subject.singleton_class` with {InjectionHook}
      #     a. This intercepts method creation to inject decorators
      #
      # @param subject [Class, Module] a container with methods we can inject
      def self.bind(subject)
        if subject.class_variables.include? :@@swank_decoration_injector
          return subject.class_variable_get(:@@swank_decoration_injector)
        end

        instance = new(subject)

        subject.singleton_class.prepend InjectionHook
        subject.class_variable_set(:@@swank_decoration_injector, instance)
        subject.class_variable_set(:@@swank_decoration_contexts, {})

        instance
      end

      # @return [Array<Swank::Decorators::MethodDecorator::Decoration>]
      attr_reader :queued_decorations

      # @param subject [Class, Module] the method container whose methods will decorate
      attr_reader :subject

      # Constructor.
      # @param subject [Class, Module] the method container whose methods will decorate
      def initialize(subject)
        @subject = subject
        @queued_decorations = {}
      end

      # Add a decorator to the queue
      #
      # The next time we add a method, it'll be injected with this decorator and
      # any others in the queue.
      #
      # @param decorator_name [Symbol] name of the decorator.
      # @see {Swank::Decorators::MethodDecorator#decorator_name}
      # @param decoration_context [Swank::Decorators::DecorationContext]
      #
      # @see {DecorationInjector::InjectionHook#method_added}
      # @see {DecorationInjector::InjectionHook#singleton_method_added}
      def queue_decoration(decorator_name, decoration_context)
        @queued_decorations[decorator_name] = decoration_context
      end

      def inject_decorations!(method_name, mode:)
        until @queued_decorations.empty?
          decorator_name, decoration_context = @queued_decorations.shift

          decoration_context.set_method_name(method_name)

          decoration_contexts[method_name] ||= {}
          decoration_contexts[method_name][mode] = decoration_context

          decoration_injection_module = decoration_injection_modules.dig(
            decorator_name,
            mode
          )

          decoration_injection_module::DecorationContextSetter.create_context_setter!(
            method_name,
            mode
          )

          decoration_injection_module.define_method(
            method_name,
            &decorators[decorator_name].wrap_block
          )
        end
      end

      # Register a type of decorator to {#subject}
      #
      # This involves:
      #
      def register_decorator!(decorator)
        decorator_name = decorator.decorator_name
        decorators[decorator_name] = decorator
        return if decoration_injection_modules[decorator_name].is_a? Hash

        instance_module = Module.new
        singleton_module = Module.new

        decoration_injection_modules[decorator_name] = {
          instance: instance_module,
          singleton: singleton_module
        }

        decoration_injection_modules[decorator_name].values.each(
          &method(:prepend_context_setter!)
        )

        @subject.prepend instance_module
        @subject.singleton_class.prepend singleton_module
      end

      def decoration_injection_modules
        @decoration_injection_modules ||= {}
      end

      def decorators
        @decorators ||= {}
      end

      def decoration_contexts
        @subject.class_variable_get(:@@swank_decoration_contexts)
      end

      def prepend_context_setter!(decoration_injection_module)
        context_setter = Module.new
        context_setter.extend Swank::Decorators::DecorationContextSetter

        decoration_injection_module.const_set(:DecorationContextSetter, context_setter)

        decoration_injection_module.prepend context_setter
      end
    end
  end
end
