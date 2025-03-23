# Example decorator that adds logging to methods
module LoggingDecorators
  extend Swank::Decorators

  def_decorator_factory :apm do |name, **options, &options_block|
    ->(func, *args, **kwargs) {
      options_block&.call(options, *args, **kwargs)

      Datadog::Tracing.trace(name, **options, &func)
    }
  end
end
