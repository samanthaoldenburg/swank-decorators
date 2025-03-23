# Swank::Decorators

Python-inspired decorators with relatively low performance costs. 

## Basic Usage

### Simple Decorators

``` ruby
require "swank/decorators"

module ThreadDecorators
  def_decorator :async do |func|
    Thread.new { func.call }
  end
end

class User < ApplicationRecord
  include ThreadDecorators

  +@async
  def asave(...)
    save(...)
  end
end
```

### Decorator Factory / Parameterized Decorators

``` ruby
require "swank/decorators"

module ThreadDecorators
  def_decorator_factory :thread_local_cache do |var_name|
    ->(func) { Thread.current[var_name] ||= func.call }
  end
end

class SessionHelper
  include ThreadDecorators
 
  @thread_local_cache[:session_uuid]
  def session_uuid
    SecureRandom.uuid
  end
end
```

## Comparison to `ActiveSupport::Callbacks`

### Speed

A major goal of mine was to make something at least as fast as Rail's `ActiveSupport::Callbacks`:

``` 
ruby 3.3.2 (2024-05-30 revision e5a195edf6) [x86_64-linux]
Warming up --------------------------------------
     Rails Callbacks    38.009k i/100ms
               Swank    51.651k i/100ms
Calculating -------------------------------------
     Rails Callbacks    395.098k (+/- 0.3%) i/s    (2.53 microseconds/i) -    798.189k in   2.020244s
               Swank    513.736k (+/- 0.2%) i/s    (1.95 microseconds/i) -      1.033M in   2.010803s

Comparison:
               Swank:   513736.3 i/s
     Rails Callbacks:   395098.0 i/s - 1.30x  slower

```

### Features

`Swank::Decorators` work similar to an `around` hook, but has a few differences.

1. Input Manipulation
2. Output Interception
3. Method Introspection

## Advanced Usage

### Input Manipulation

Similar to prepending a method, you can intercept the arguments of a method and
modify what gets passed on.

> [!NOTE]
>
> Input clobbering gets passed on to decorators that haven't run yet (see the `cha_cha_slide` below).

You can work with the positional and keyword arguments passed to the decorated
method, but not the block passed to the decorated method.

``` ruby
module InputClobber
  extend Swank::Decorators

  def_decorator :pos_reversal do |func, *args, **kwargs|
    func.call(*args.reverse, **kwargs)
  end
end

class Foo
  include InputClobber

  +@pos_reversal
  def self.division(a, b)
    a / b
  end

  +@pos_reversal
  +@pos_reversal
  def self.cha_cha_slide(a, b)
    a / b
  end
end

# => Foo.division(2.0, 3.0) # => 3.0
# => Foo.cha_cha_slide(2.0, 3.0) # => 0.6666666666666666666
```

### Method Introspection

#### Dynamically Getting the Decorated Method's Name

You can use `func.method_name` to get the name of the method we are currently decorating.

``` ruby
require "swank/decorators"

module ThreadDecorators
  def_decorator_factory :thread_local_cache do |var_name = nil|
    ->(func) { 
      thread_local_var_name = var_name ? var_name : func.method_name
      Thread.current[thread_local_var_name] ||= func.call 
    }
  end
end

class SessionHelper
  include ThreadDecorators
 
  +@thread_local_cache
  def session_uuid
    SecureRandom.uuid
  end
end
```
