# lib/decoration_injection.rb

module Swank
  module Decorators
    # The module that actually overrides methods to run the decorators
    module DecorationInjection
      # Behavior shared by {InstanceLevel} and {SingletonLevel}
      # @api private
      module SharedModuleLevelBehavior
        def clone(*)
          super.tap { |m| m.instance_variable_set(:@decorator_chains, {}) }
        end

        # @return [Hash{Symbol => DecoratorBase}]
        def decorator_chains
          @decorator_chains
        end

        # Add decorators to the chain of the given method
        #
        # @param method_name [Symbol] the method we're adding decorators to
        # @param decorator_chain [DecoratorBase] a linked list of decorators
        # @return [DecoratorBase] the new decorator chain
        def add_to_decorator_chain!(method_name, decorator_chain)
          if decorator_chains[method_name]
            decorator_chains[method_name].add_to_chain!(decorator_chain)
          else
            decorator_chains[method_name] = decorator_chain
            create_decoration_method!(method_name)
          end

          decorator_chains[method_name]
        end

        # Create the prepended method that will execute the decorations for a method
        # @param method_name [Symbol] the method we're adding decorators to
        # @return [void]
        def create_decoration_method!(method_name)
          class_eval <<~RUBY, __FILE__, __LINE__ + 1
            def #{method_name}(*args, **kwargs, &original_method_block)
              run_decorations(:#{method_name}, *args, **kwargs) do |*a, **k|
                super(*a, **k, &original_method_block)
              end
            end
          RUBY
        end
      end

      # Behavior prepended by {InstanceLevel} and {SingletonLevel}
      # @api private
      module SharedPrependedBehavior
        def run_decorations(method_name, *args, **kwargs, &block)
          call_sequence = fetch_swank_decorator_chain(method_name)

          invocation = DecoratorExecutionChain.new do |*a, **k|
            current = call_sequence
            value = nil
            # Preserve updates to params, or re-supply them if previous
            # decorator didn't supply them
            a.none? ? a = args : args = a
            k.none? ? k = kwargs : kwargs = k

            if current.nil?
              value = instance_exec(*a, **k, &block)
            else
              call_sequence = call_sequence.nested
              value = instance_exec(invocation, *a, **k, &current.wrap_block)
            end

            value
          end

          instance_exec(&invocation)
        end
      end

      # Instance-level prepended module prototype
      # @see {DecorationInjection}
      # @see {DecorationInjection::SharedPrependedBehavior#run_decorations}
      module InstanceLevel
        extend SharedModuleLevelBehavior
        include SharedPrependedBehavior

        # The name of this module should have when working with `const_set`
        CONST_NAME = :SwankDecorationInjection

        def self.prepend_to(obj)
          modul = clone
          obj.const_set(CONST_NAME, modul)
          obj.prepend modul
          modul
        end

        def fetch_swank_decorator_chain(method_name)
          self.class::SwankDecorationInjection.decorator_chains[method_name]
        end
      end

      # Class-level prepended module prototype
      # @see {DecorationInjection}
      # @see {DecorationInjection::SharedPrependedBehavior#run_decorations}
      module SingletonLevel
        extend SharedModuleLevelBehavior
        include SharedPrependedBehavior

        # The name of this module should have when working with `const_set`
        CONST_NAME = :SwankSingletonDecorationInjection

        # Prepend this module to the singleton class
        def self.prepend_to(obj)
          modul = clone
          obj.const_set(CONST_NAME, modul)
          obj.singleton_class.prepend modul
          modul
        end

        # @return [DecoratorBase]
        def fetch_swank_decorator_chain(method_name)
          self::SwankSingletonDecorationInjection.decorator_chains[method_name]
        end
      end
    end
  end
end
