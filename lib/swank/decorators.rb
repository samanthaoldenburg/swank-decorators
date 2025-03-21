# frozen_string_literal: true

require_relative "decorators/version"
require "swank/decorators/decoration_injector"
require "swank/decorators/decorator_without_context"
require "swank/decorators/decorator_with_context"

module Swank
  module Decorators
    # Define a basic decorator
    # @param name [Symbol] the name of the decorator
    # @return [Swank::Decorators::DecoratorWithoutContext]
    #
    # @xample
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
    #     const_static!
    #     def self.all_user_roles
    #       select(:role).uniq.map(&:to_sym)
    #     end
    #   end
    def def_decorator(name, &block)
      set_decorator(DecoratorWithoutContext, name, &block)
    end

    # Define a factory that can create decorations
    # @param name [Symbol] the name of the decorator
    # @return [Swank::Decorators::DecoratorWithContext]
    #
    # @example
    #   module RoundingDecorations
    #     extend Swank::Decorations
    #
    #     def_decorator_factory :round_result do |to_precision: 0|
    #       ->(*args, **kwargs, &block) {
    #         super(*args, **kwargs, &block)&.round(to_precision)
    #       }
    #     end
    #   end
    #
    #   class LoanCalculator
    #     include RoundingDecorations
    #
    #     # Initial principal amount, in dollars
    #     # @return [Float]
    #     attr_reader :amount
    #
    #     # Number of installments in the loan
    #     # @return [Integer]
    #     attr_reader :term
    #
    #     # Get the monthly payment amoutn
    #     # @return [Float]
    #     round_result! to_precision: 2 # round to the nearest cent
    #     def calculate_installment_amount
    #       amount / term.to_f
    #     end
    def def_decorator_factory(name, &block)
      set_decorator(DecoratorWithContext, name, &block)
    end

    # The decorators defined in the namespace
    def swank_decorators
      @swank_decorators ||= {}
    end

    # Inclusion hook
    # @param obj [Class, Module]
    # @return [void]
    # @api private
    def included(obj)
      bind_to_object!(obj)
      super
    end

    # Inject the decorator methods into the class
    # @param obj [Class, Module]
    # @return [void]
    # @api private
    def bind_to_object!(obj)
      decoration_injector = Swank::Decorators::DecorationInjector.bind(obj)
      decoration_injector.register_decorators! self
    end

    class Error < StandardError; end

    private

    def set_decorator(decorator_class, name, &block)
      swank_decorators[name] ||= Class.new(decorator_class)
      swank_decorators[name].setup(name, block)
      swank_decorators[name]
    end
  end
end
