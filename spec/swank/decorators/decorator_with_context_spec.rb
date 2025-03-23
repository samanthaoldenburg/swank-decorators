# decorators_with_context_spec.rb

require "pry"
RSpec.describe Swank::Decorators::DecoratorWithContext do
  let!(:decorators) {
    Module.new do
      extend Swank::Decorators

      def_decorator_factory :add do |num|
        ->(func) { func.call + num }
      end

      def_decorator_factory :subtract do |by: 1|
        ->(func) { func.call - by }
      end

      def_decorator_factory :mult do |num|
        ->(func) { func.call * num }
      end

      def_decorator_factory :perform_additional_processing do |b|
        ->(func) { b.call(func.call) }
      end
    end.tap { |m| stub_const("MathDecorators", m) }
  }

  let(:dummy) {
    Module.new do
      include MathDecorators

      @add >> 3
      def self.foo
        1
      end

      @mult >> 3
      @add >> 10
      def self.bar(a, b)
        a * b
      end

      add_singleton_method :bar, 3
    end
  }

  it "can create decorators that can be flexed with parameters" do
    expect(dummy.foo).to eq 4
    expect(dummy.bar(2, 3)).to eq 57
  end
end
