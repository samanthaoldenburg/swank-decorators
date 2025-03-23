# lib/decoration_injector.rb

require "swank/decorators/ivar_dsl"

module Swank
  module Decorators
    class DecorationInjector
      # A proc runs all the decorators for a method
      class DecoratorChain < Proc
        # The name of the method we are currently applying decorators to
        def method_name
          binding.local_variable_get(:method_name)
        end
      end

      # Module that actually overrides methods to add injections
      module DecorationPrepender
        def self.prepended(klass)
          klass.instance_variable_set(:@swank_decorators, {})
        end

        def self.clone_for_scope(scope)
          dup.tap do |m|
            m.class_variable_set(:@@swank_decorators, {})
            deco_source = case scope
            when :instance then "self.class::SwankDecorations"
            when :singleton then "self::SwankSingletonDecorations"
            end

            m.class_eval <<~RUBY, __FILE__, __LINE__ + 1
              def compile_decorators(method_name)
                #{deco_source}.decorators[method_name]
              end

              def self.decorators
                @@swank_decorators
              end
            RUBY
          end
        end

        def run_decorations(method_name, *args, **kwargs, &block)
          call_sequence = compile_decorators(method_name)
          value = nil
          current = call_sequence

          invocation = DecoratorChain.new do |*a, **k|
            # Preserve updates to params, or re-supply them if previous
            # decorator didn't supply them
            a.none? ? a = args : args = a
            k.none? ? k = kwargs : kwargs = k

            current = call_sequence
            if current.nil?
              value = instance_exec(*a, **k, &block)
            else
              call_sequence = call_sequence.nested
              value = instance_exec(invocation, *a, **k, &current.wrap_block)
            end

            value
          end

          invocation.call
        end
      end

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
        @queued_decorations = nil
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
        new_decorator = decorator_class.new(*args, **kwargs, &block)
        if @queued_decorations.nil?
          @queued_decorations = new_decorator
        else
          @queued_decorations.add_to_chain! new_decorator
        end

        new_decorator
      end

      # Inject the queued decorations into the injector
      def inject_decorations!(method_name, mode:)
        return unless @queued_decorations

        decorations = @queued_decorations
        @queued_decorations = nil

        decoration_injection_module = fetch_decorator_prepend_module(mode)

        if decoration_injection_module.decorators[method_name]
          decoration_injection_module.decorators[method_name].add_to_chain!(decorations)
        else
          decoration_injection_module.decorators[method_name] = decorations

          decoration_injection_module.class_eval <<~RUBY, __FILE__, __LINE__ + 1
            def #{method_name}(*args, **kwargs, &original_method_block)
              run_decorations(:#{method_name}, *args, **kwargs) do |*a, **k|
                super(*a, **k, &original_method_block)
              end
            end
          RUBY
        end

        decorations
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

      # @param decorator_name [Symbol]
      # @param scope [:instance, :singleton]
      # @return [Module]
      def fetch_decorator_prepend_module(scope)
        modul = decoration_injection_modules[scope]

        return modul if modul

        modul = DecorationPrepender.clone_for_scope(scope)

        decoration_injection_modules[scope] = modul

        case scope
        when :instance
          @subject.prepend modul
          subject.const_set(:SwankDecorations, modul)
        when :singleton
          @subject.singleton_class.prepend modul
          subject.const_set(:SwankSingletonDecorations, modul)
        else
          raise ArgumentError, "scope must be :instance or :singleton"
        end

        modul
      end

      # Register a type of decorator to {#subject}
      #
      # This involves creating modules that prepend {#subject} and
      # `subject.singleton_class`
      def register_decorator!(decorator_name, decorator_class)
        decorators[decorator_name] = decorator_class
        decoration_injection_modules[decorator_name] = {}
      end

      def define_decorator_method!(decorator_name)
        subject.singleton_class.class_eval <<~RUBY, __FILE__, __LINE__ + 1
          def #{decorator_name}(method_name, ...)
            injector = class_variable_get(:@@swank_decoration_injector)
            injector.queue_decoration(:#{decorator_name}, ...)
            injector.inject_decorations!(method_name, mode: :instance)
          end

          def #{decorator_name}_singleton_method(method_name, ...)
            injector = class_variable_get(:@@swank_decoration_injector)
            injector.queue_decoration(:#{decorator_name}, ...)
            injector.inject_decorations!(method_name, mode: :singleton)
          end
        RUBY

        subject.instance_variable_set(
          :"@#{decorator_name}",
          IvarDsl.new(decorator_name, self)
        )
      end
    end
  end
end
