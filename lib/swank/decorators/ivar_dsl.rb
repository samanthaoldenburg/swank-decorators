module Swank
  module Decorators
    # Helper class to enable ivar DSL
    class IvarDsl
      # Name of the decorator represented by this Ivar
      # @return [Symbol]
      attr_reader :decorator_name

      # The injector class that created this DSL helper
      # @return [Swank::Decorators::DecorationInjector]
      attr_reader :injector

      # @param injector [Swank::Decorators::DecorationInjector]
      def initialize(decorator_name, injector)
        @decorator_name = decorator_name
        @injector = injector
      end

      # Syntactic-sugar useful for a {DecoratorWithContext}
      #
      # @example
      #   module ThreadDecorators
      #     extend Swank::Decorators
      #
      #     # Decorate the method to run in a Thread
      #     def_decorator :async do |*args, **kwargs, &block|
      #       Thread.new { super(*args, **kwargs, &block) }
      #     end
      #
      #     # Decorate the method to memoize in a Thread-local variable
      #     #
      #     # @example
      #     #   class SessionHelper
      #     #     include ThreadDecorators
      #     #
      #     #     # @return [String] a UUID
      #     def_decorator_factory :thread_local_cache do |var_name|
      #       ->(*args, **kwargs, &block) {
      #         Thread.current[var_name] ||= super(*args, **kwargs, &block)
      #       }
      #     end
      #   end
      #
      #   class SessionHelper
      #     extend ConstStaticMethod
      #
      #     # @return [String] UUID
      #     @thread_local_cache.(:session_uuid)
      #     def self.session_uuid
      #       SecureRandom.uuid
      #     end
      #   end
      def call(...)
        injector.queue_decoration(decorator_name, ...)
      end

      # Syntactic-sugar useful for a {DecoratorWithContext}
      #
      # @example
      #   module ThreadDecorators
      #     extend Swank::Decorators
      #
      #     # Decorate the method to run in a Thread
      #     def_decorator :async do |*args, **kwargs, &block|
      #       Thread.new { super(*args, **kwargs, &block) }
      #     end
      #
      #     # Decorate the method to memoize in a Thread-local variable
      #     #
      #     # @example
      #     #   class SessionHelper
      #     #     include ThreadDecorators
      #     #
      #     #     # @return [String] a UUID
      #     def_decorator_factory :thread_local_cache do |var_name|
      #       ->(*args, **kwargs, &block) {
      #         Thread.current[var_name] ||= super(*args, **kwargs, &block)
      #       }
      #     end
      #   end
      #
      #   class SessionHelper
      #     extend ConstStaticMethod
      #
      #     # @return [String] UUID
      #     @thread_local_cache[:session_uuid]
      #     def self.session_uuid
      #       SecureRandom.uuid
      #     end
      #   end
      def [](...)
        injector.queue_decoration(decorator_name, ...)
      end

      # Syntactic-sugar useful for a {DecoratorWithoutContext}
      # @example
      #   module ConstStaticMethods
      #     extend Swank::Decorations
      #
      #     def_decorator_factory :const_static do |*args, **kwargs, &block|
      #       const_name = "CONST_STATIC_#{__method__}"
      #
      #       const_get(const_name)
      #     rescue NameError => e
      #       super(*args, **kwargs, &block).tap { |result| const_set(const_name, result) }
      #     end
      #   end
      #
      #   class User < ApplicationRecord
      #     extend ConstStaticMethod
      #
      #     # Get a list of all roles in the user database
      #     # @return [Array<Symbol>]
      #     !@const_static
      #     def self.all_user_roles
      #       select(:role).uniq.map(&:to_sym)
      #     end
      #   end
      def +@(...)
        injector.queue_decoration(decorator_name, ...)
      end
      alias_method :!, :+@

      # Syntactic-sugar useful for a {DecoratorWithContext}
      #
      # @example
      #   module ThreadDecorators
      #     extend Swank::Decorators
      #
      #     # Decorate the method to run in a Thread
      #     def_decorator :async do |*args, **kwargs, &block|
      #       Thread.new { super(*args, **kwargs, &block) }
      #     end
      #
      #     # Decorate the method to memoize in a Thread-local variable
      #     #
      #     # @example
      #     #   class SessionHelper
      #     #     include ThreadDecorators
      #     #
      #     #     # @return [String] a UUID
      #     def_decorator_factory :thread_local_cache do |var_name|
      #       ->(*args, **kwargs, &block) {
      #         Thread.current[var_name] ||= super(*args, **kwargs, &block)
      #       }
      #     end
      #   end
      #
      #   class SessionHelper
      #     extend ConstStaticMethod
      #
      #     # @return [String] UUID
      #     @thread_local_cache >> :session_uuid
      #     def self.session_uuid
      #       SecureRandom.uuid
      #     end
      #   end
      def >>(other)
        injector.queue_decoration(decorator_name, other)
      end

      alias_method :>=, :>>
    end
  end
end
