# decorators_with_context_spec.rb

RSpec.describe Swank::Decorators::DecoratorWithContext do
  let!(:decorators) {
    Module.new do
      extend Swank::Decorators

      def_decorator_factory :add do |num|
        ->(func, a, *args, **kwargs) {
          func.call(a + 1, *args, **kwargs) + num
        }
      end

      def_decorator_factory :subtract do |by: 1|
        ->(func, *) { func.call - by }
      end

      def_decorator_factory :mult do |num|
        ->(func, *) { func.call * num }
      end
    end.tap { |m| stub_const("MathDecorators", m) }
  }

  let(:dummy) {
    Module.new do
      include MathDecorators

      @add >> 3
      def self.foo(a = 1)
        a
      end

      @mult >> 3
      @add >> 10
      def self.bar(a, b)
        result = a * b
        result += yield if block_given?
        result
      end

      add_singleton_method :bar, 3
      mult_singleton_method :bar, 1
    end
  }

  it "can create decorators that can be flexed with parameters" do
    expect(dummy.foo(1)).to eq 5

    # Explanation
    #
    # 1. Using the @add decorator twice is going to add 2 to the first param of
    #    `bar`
    #   a. This essentially rewrites the call to `bar(4, 3) { 1 }`
    #   b. This resolves to **13**
    # 2. We then multiply this result by 1 (`mult_singleton_method :bar, 1`)
    #   a. This resolves to **13**
    # 3. We then add 3 to the result (`add_singleton_method :bar, 3`)
    #   a. This resolves to **16**
    # 4. We then add 10 to the result (`@add >> 10`)
    #   a. This resolves to **26**
    # 5. We then multiply the result by 3 (`@mult >> 3`)
    #   a. This resolves to **78**
    expect(dummy.bar(2, 3) { 1 }).to eq 78
  end
end
