# frozen_string_literal: true

RSpec.describe Swank::Decorators do
  it "has a version number" do
    expect(Swank::Decorators::VERSION).not_to be nil
  end

  describe "a module that extends Swank::Decorators" do
    let!(:modul) {
      Module.new.tap { |m|
        stub_const("TestModule", m)
        TestModule.extend Swank::Decorators
      }
    }

    it "defines the macros .def_decorator and .def_decorator_factory" do
      expect(defined?(TestModule.def_decorator)).to be_truthy
      expect(defined?(TestModule.def_decorator_factory)).to be_truthy
    end

    shared_examples "shared_decorator_behavior" do |**kwargs|
      macro, decorator_name = kwargs.to_a.first

      let(:decorator_class) {
        case macro
        when :def_decorator then Swank::Decorators::DecoratorWithoutContext
        when :def_decorator_factory then Swank::Decorators::DecoratorWithContext
        end
      }

      it { is_expected.to be_a Class }
      it { is_expected.to be < decorator_class }

      it "registers a new decorator class to the module" do
        expect { subject }.to change {
          TestModule.swank_decorators.count
        }.by(1).and change {
          TestModule.swank_decorators.key?(decorator_name)
        }.to(true)
      end

      let(:new_def) { -> { puts "hi" } }

      it "can be overriden with new behavior" do
        subject

        decorator = TestModule.swank_decorators[decorator_name]

        expect(decorator).to receive(:setup).with(decorator_name, new_def)
        expect(Class).not_to receive(:new).with(decorator_class)

        expect { TestModule.send(macro, decorator_name, &new_def) }.not_to change {
          TestModule.swank_decorators.count
        }

        expect(TestModule.swank_decorators[decorator_name]).to be decorator
      end

      other_macro, other_class = case macro
      when :def_decorator then [:def_decorator_factory, Swank::Decorators::DecoratorWithContext]
      when :def_decorator_factory then [:def_decorator, Swank::Decorators::DecoratorWithoutContext]
      end

      it "can be converted to a #{other_class} using #{other_macro}" do
        subject

        expect { TestModule.send(other_macro, decorator_name, &new_def) }.to change {
          TestModule.swank_decorators[decorator_name].superclass
        }.from(decorator_class).to(other_class)
      end
    end

    describe ".def_decorator" do
      subject {
        TestModule.def_decorator :async do |*args, **kwargs, &block|
          Thread.new { super(*args, **kwargs, &block) }
        end
      }

      include_examples "shared_decorator_behavior", def_decorator: :async
    end

    describe ".def_decorator_factory" do
      subject {
        TestModule.def_decorator_factory :thread_local_cache do |var_name|
          ->(*args, **kwargs, &block) {
            Thread.current[var_name] ||= super(*args, **kwargs, &block)
          }
        end
      }

      include_examples "shared_decorator_behavior", def_decorator_factory: :thread_local_cache
    end

    describe ".included(klass)" do
      subject { klass.include TestModule }
      let(:klass) { Class.new }
      let(:injector) { Swank::Decorators::DecorationInjector.new(klass) }

      before {
        allow(Swank::Decorators::DecorationInjector).to receive(:bind).and_return(injector)
        allow(injector).to receive(:register_decorators!)
      }

      it "binds a DecorationInjector to klass" do
        expect(Swank::Decorators::DecorationInjector).to receive(:bind).with(klass)
        subject
      end

      it "registers its decorators with the injector" do
        expect(injector).to receive(:register_decorators!).with(TestModule)
        subject
      end
    end
  end
end
