require "./spec/fixtures/const_static_decorator"
require "./spec/fixtures/logging_decorators"
require "./spec/fixtures/thread_decorators"

RSpec.describe "Decorator DSL" do
  let!(:klass) {
    Class.new {
      include ConstStaticDecorator
      include LoggingDecorators
      include ThreadDecorators

      def self.random_num
        rand(1..1000)
      end
    }.tap { |t| stub_const("TestClass", t) }
  }

  context "For decorators without arguments" do
    describe "I-Var Syntax" do
      describe "!@decorator_name" do
        subject {
          TestClass.class_eval {
            !@const_static
            def self.foo
              random_num
            end
          }
        }

        it "can be used before the method definition" do
          subject
          value = TestClass.foo

          5.times { expect(TestClass.foo).to eq value }
        end
      end

      describe "Inline Decoration" do
        describe "`decerator_name`_singleton_method def ..." do
          subject {
            TestClass.class_eval {
              const_static_singleton_method def self.foo
                random_num
              end
            }
          }

          it "can be used for a inline-decoration on a class method definition" do
            subject
            value = TestClass.foo

            5.times { expect(TestClass.foo).to eq value }
          end
        end

        describe "decerator_name def ..." do
          subject {
            TestClass.class_eval {
              async def foo
                self.class.random_num
              end
            }
          }

          it "can be used for a inline-decoration on a class method definition" do
            subject

            call = TestClass.new.foo
            expect(call).to be_a Thread

            call.join
            expect(call.value).to be_an Integer
          end
        end
      end

      describe "Post Definition Decoration" do
        describe "`decorator_name`_singleton_method :method_name" do
          subject {
            TestClass.class_eval {
              def self.foo
                random_num
              end
              const_static_singleton_method :foo
            }
          }

          it "can be used to decorate a singleton method after definition (like `private_singleton_method`)" do
            subject
            value = TestClass.foo

            5.times { expect(TestClass.foo).to eq value }
          end
        end

        describe "decorator_name :method_name" do
          subject {
            TestClass.class_eval {
              def foo
                self.class.random_num
              end
              async :foo
            }
          }

          it "can be used to decorate a method after definition (like `private`)" do
            subject

            call = TestClass.new.foo
            expect(call).to be_a Thread

            call.join
            expect(call.value).to be_an Integer
          end
        end
      end
    end
  end

  context "For decorators that take one postional argument" do
    describe "I-Var Syntax" do
      describe "@decorator_name >> var syntax" do
        subject {
          TestClass.class_eval {
            @thread_local_cache >> :rand_seed
            def self.rand_seed
              Random.new_seed
            end
          }
        }

        it "can be used to decorate the method before declaration" do
          subject

          value = TestClass.rand_seed
          5.times { expect(TestClass.rand_seed).to eq value }

          value_2 = Thread.new {
            v2 = TestClass.rand_seed
            5.times { expect(TestClass.rand_seed).to eq v2 }
            v2
          }.join.value

          expect(value_2).not_to eq value
        end
      end
    end
  end

  context "For decorators that take multiple arguments" do
    describe "I-Var Syntax" do
      subject {
        TestClass.class_eval do
          @apm["TestUser.ssn_match_p", tags: {environment: Rails.env}] do |options, id:, **|
            # Only add user_id as a tag, SSN should not be a tag
            options[:tags][:user_id] = id
          end
          def self.ssn_match?(id:, ssn:)
            id == ssn # Never use SSNs as IDs in your DB
          end
        end
      }

      let(:fake_dog) {
        Class.new do
          def self.trace(name, **options)
            yield if block_given?
          end
        end
      }
      let(:rails_stub) { double("Rails", env: :production) }

      before {
        stub_const("Datadog::Tracing", fake_dog)
        stub_const("Rails", rails_stub)
      }

      let(:id) { 2194 }
      let(:ssn) { "REDACTED" }

      describe "@decorator_name[*args, **kwargs, &block] >> var syntax" do
        it "can be used with complex decorator factories" do
          subject

          expect(Datadog::Tracing).to receive(:trace).with(
            "TestUser.ssn_match_p",
            {tags: {environment: :production, user_id: id}}
          ).and_yield

          expect(TestClass.ssn_match?(id:, ssn:)).to be false
        end
      end
    end
  end
end
