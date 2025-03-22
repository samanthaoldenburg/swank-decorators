module ConstStaticDecorator
  extend Swank::Decorators

  def_decorator :const_static do
    const_name = "CONST_STATIC_#{__method__}"

    const_get(const_name)
  rescue NameError => _
    super().tap { |result| const_set(const_name, result) }
  end
end
