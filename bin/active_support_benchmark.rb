#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "swank/decorators"
require "active_support/callbacks"

module ConstStatic
  extend Swank::Decorators

  def_decorator :const_static do |func|
    const_name = "CONST_STATIC_#{func.method_name}"

    const_get(const_name)
  rescue NameError => _
    func.call.tap { |result| const_set(const_name, result) }
  end
end

class Feature
  include ConstStatic

  !@const_static
  def self.bar
    rand(1..10000)
  end

  !@const_static
  def self.baz
    rand(1..10000)
  end
end

class RailsTest
  include ActiveSupport::Callbacks
  define_callbacks :bar
  define_callbacks :baz

  set_callback :bar, :around do |obj, fun|
    const_name = :"CONST_RESULT_#{'bar'}"
    if self.class.constants.include?(const_name)
      self.class.const_get(const_name)
    else
      fun.call.tap { |result| self.class.const_set(const_name, result) }
    end
  end

  set_callback :baz, :around do |obj, fun|
    const_name = :"CONST_RESULT_#{'bar'}"
    if self.class.constants.include?(const_name)
      self.class.const_get(const_name)
    else
      fun.call.tap { |result| self.class.const_set(const_name, result) }
    end
  end

  def bar
    run_callbacks :bar do
      rand(1..10000)
    end
  end

  def baz
    run_callbacks :baz do
      rand(1..10000)
    end
  end
end

rails_test = RailsTest.new

require "benchmark/ips"

Benchmark.ips do |x|
  x.config(warmup: 1, time: 2)

  x.report("Rails Callbacks") do |times|
    i = 0
    while i < times
      i += 1

      rails_test.bar
    end
  end

  x.report("Swank") do |times|
    i = 0
    while i < times
      i += 1

      Feature.bar
    end
  end

  x.compare!
end
