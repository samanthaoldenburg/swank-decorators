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

        # @return [Swank::Decorators::DecorationInjector]
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
      # @param decorator [Swank::Decorator::DecoratorBase] the decorator
      #
      # @see {DecorationInjector::InjectionHook#method_added}
      # @see {DecorationInjector::InjectionHook#singleton_method_added}
      def queue_decoration(decorator_name, *args, **kwargs, &block)
        decorator_class = decorators[decorator_name]
        @queued_decorations[decorator_name] = decorator_class.new(*args, **kwargs, &block)
      end

      # Inject the queued decorations into the injector
      def inject_decorations!(method_name, mode:)
        until @queued_decorations.empty?
          decorator_name, decorator = @queued_decorations.shift

          decoration_injection_module = decoration_injection_modules.dig(
            decorator_name,
            mode
          )

          decoration_injection_module.define_method(
            method_name,
            &decorator.wrap_block
          )
        end
      end

      # Register an entire set of decorators from a module
      # @param decorators_modules [Module] a module that has extended `Swank::Decorators`
      def register_decorators!(decorators_module)
        decorators_module.swank_decorators.each do |decorator_name, decorator_class|
          if decorators[decorator_name]
            warn "Decorator #{decoration_name} already defined for #{subject}"
          end

          register_decorator!(decorator_name, decorator_class)
          define_decorator_method!(decorator_name)
        end
      end

      # @return [Hash{Symbol => Class<Swank::Decoratos::DecoratorBase>}]
      def decorators
        @decorators ||= {}
      end

      # @return [Hash{Symbol => Hash{:instance, :singleton => Module}}]
      def decoration_injection_modules
        @decoration_injection_modules ||= {}
      end

      private

      # Register a type of decorator to {#subject}
      #
      # This involves creating modules that prepend {#subject} and
      # `subject.singleton_class`
      def register_decorator!(decorator_name, decorator_class)
        decorators[decorator_name] = decorator_class
        return if decoration_injection_modules[decorator_name].is_a? Hash

        instance_module = Module.new
        singleton_module = Module.new

        decoration_injection_modules[decorator_name] = {
          instance: instance_module,
          singleton: singleton_module
        }

        @subject.prepend instance_module
        @subject.singleton_class.prepend singleton_module
      end

      def define_decorator_method!(decorator_name)
        subject.singleton_class.class_eval <<~RUBY, __FILE__, __LINE__ + 1
          def #{decorator_name}!(...)
            class_variable_get(:@@swank_decoration_injector).queue_decoration(
              :#{decorator_name}, ...
            )
          end
        RUBY
      end

    end
  end
end
