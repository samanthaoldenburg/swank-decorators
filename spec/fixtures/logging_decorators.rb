# Example decorator that adds logging to methods
module LoggingDecorators
  def_decorator_factory :apm do |name, options_setup: nil, **options|
    ->(*args, **kwargs, &block) {
      if options_setup.is_a?(Proc)
        bindin
      end
      Datadog::Tracing.trace(name, **options) do ||

      end
    }
  end
end
