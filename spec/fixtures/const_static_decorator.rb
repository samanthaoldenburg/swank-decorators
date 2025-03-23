module ConstStaticDecorator
  extend Swank::Decorators

  def_decorator :const_static do |func|
    const_name = "CONST_STATIC_#{func.method_name}"

    const_get(const_name)
  rescue NameError => _
    func.call.tap { |result| const_set(const_name, result) }
  end
end
