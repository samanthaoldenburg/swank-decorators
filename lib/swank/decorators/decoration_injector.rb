require "swank/decorators/ivar_dsl"
require "swank/decorators/decoration_injection"
require "swank/decorators/decorator_execution_chain"

module Swank
  module Decorators
    # A class-level variable that lives in your Class/Module
    #
    # It (often via modules it coordinates):
    #   1. Defines the macros/DSL used to declare declarations,
    #      via {#define_decorator_methods!}
    #
    #   2. Injects the Class/Module with {DecorationInjection::InstanceLevel}
    #      and {DecorationInjection::SingletonLevel} modules.
    #
    #   3. Manages {#queued_decorations} and injects them when a method is added,
    #      via {MethodAddedHooks}
    #
    # An instance of +DecorationInjector+ is created a Class/Module first time
    # the it's passed to the {.bind} method. +.bind+ is called whenever a
    # decorator module is included onto a Class/Module, via
    # {Swank::Decorators#included}
    class DecorationInjector
      # Module that intercepts method_adds to inject decorators
      module MethodAddedHooks
        # Inject the added method with all queued instance method decorators
        # @param [Symbol] method_name
        # @return [void]
        def method_added(method_name)
          decoration_injector.inject_decorations!(method_name.to_sym, mode: :instance)

          super
        end

        # Inject the added method with all queued singleton method decorators
        # @param [Symbol] method_name
        # @return [void]
        def singleton_method_added(method_name)
          decoration_injector.inject_decorations!(method_name.to_sym, mode: :singleton)

          super
        end

        private

        # @return [Swank::Decorators::DecorationInjector]
        def decoration_injector
          # @type self: Class | Module
          class_variable_get(:@@swank_decoration_injector)
        end
      end

      # Set up decoration injection for +subject+
      #
      # Does the following.
      #   1. Ensures +subject+ has a class-level variable +@@swank_decoration_injector+
      #     a. If not, set it to an instance of {DecorationInjector}
      #   2. Prepend +subject.singleton_class+ with {MethodAddedHooks}
      #     a. This intercepts method creation to inject decorators
      #
      # @param [Class, Module] subject  a container with methods we can inject
      def self.bind(subject)
        if subject.class_variables.include? :@@swank_decoration_injector
          return subject.class_variable_get(:@@swank_decoration_injector)
        end

        instance = new(subject)

        subject.singleton_class.prepend MethodAddedHooks
        subject.class_variable_set(:@@swank_decoration_injector, instance)

        instance
      end

      # Linked-list of queued decorators
      # @return Swank::Decorators::DecoratorChain
      attr_reader :queued_decorations

      # @param [Class, Module] subject  the method container whose methods will decorate
      attr_reader :subject

      # Constructor.
      # @param [Class, Module] subject  the method container whose methods will decorate
      def initialize(subject)
        @subject = subject
        @queued_decorations = nil
      end

      # Add a decorator to the queue
      #
      # The next time we add a method, it'll be injected with this decorator and
      # any others in the queue.
      #
      # @param [Swank::Decorator::DecoratorBase] decorator  the decorator
      #
      # @see {DecorationInjector::MethodAddedHooks#method_added}
      # @see {DecorationInjector::MethodAddedHooks#singleton_method_added}
      def queue_decoration(decorator_name, *args, **kwargs, &block)
        decorator_klass = decorators[decorator_name] 
        new_decorator = decorator_klass.new( # steep:ignore UnexpectedBlockGiven
          *args, # steep:ignore UnexpectedPositionalArgument
          **kwargs,
          &block 
        ) 
        if @queued_decorations.nil?
          @queued_decorations = new_decorator
        else
          @queued_decorations.add_to_chain! new_decorator
        end

        new_decorator
      end

      # Inject the queued decorations into the injector
      # @param [Symbol] method_name  the name of the method we're injecting decorators onto
      # @param [:instance, :singleton] mode
      def inject_decorations!(method_name, mode:)
        return unless @queued_decorations

        decorations = @queued_decorations
        @queued_decorations = nil

        decoration_injection_module = fetch_decorator_injection_module(
          decoration_injection_base_module(mode)
        )

        decoration_injection_module.add_to_decorator_chain!(method_name, decorations)
      end

      # Register an entire set of decorators from a module
      # @param [Module] decorators_module  a module that has extended +Swank::Decorators+
      def register_decorators!(decorators_module)
        decorators_module.swank_decorators.each do |decorator_name, decorator_class|
          if decorators[decorator_name]
            warn "Decorator #{decorator_name} already defined for #{subject}"
          end

          register_decorator!(decorator_name, decorator_class)
          define_decorator_methods!(decorator_name)
        end
      end

      # Map of decorator names to decoration defintions
      # @return [Hash{Symbol => Class<Swank::Decorators::DecoratorBase>}]
      def decorators
        @decorators ||= {}
      end

      # Define the class-level DSL used to declare decorations.
      #
      # It:
      #   1. Defines a +"decorator_name"+ class macro that can decorate
      #      instance methods
      #   2. Defines a +"decorator_name"_singleton_method+ class macro that can
      #      decorate class-level methods
      #   3. Creates a class-level instance variable +@"decorator_name"+ (see
      #      {IvarDsl})
      #
      # @param [Symbol] decorator_name
      # @return [void]
      def define_decorator_methods!(decorator_name)
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

      private

      # Get the DecorationInjection module prepended to subject.
      #
      # @base_module [Module] should be {DecorationInjection::InstanceLevel} or
      #   {DecorationInjection::SingletonLevel}
      # @return [Module]
      def fetch_decorator_injection_module(base_module)
        subject.const_get(base_module.const_name)
      rescue NameError => _
        base_module.prepend_to(subject)
      end

      # Get base DecorationInjection module for the given scope
      # @param [:instance, :singleton] scope
      # @return [DecorationInjection::InstanceLevel] if scope is +:instance+
      # @return [DecorationInjection::SingletonLevel] if scope is +:singleton+
      def decoration_injection_base_module(scope)
        case scope
        when :instance then DecorationInjection::InstanceLevel
        when :singleton then DecorationInjection::SingletonLevel
        else
          raise ArgumentError, "scope must be :instance or :singleton"
        end
      end

      # Register a type of decorator to {#subject}
      #
      # This involves creating modules that prepend {#subject} and
      # +subject.singleton_class+
      def register_decorator!(decorator_name, decorator_class)
        decorators[decorator_name] = decorator_class
      end
    end
  end
end
