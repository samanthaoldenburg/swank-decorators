require "pry"
# An example decorator module with decorators for thread operations
module ThreadDecorators
  extend Swank::Decorators

  # Decorate the method to run in a Thread
  #
  # @example
  #   class User < ApplicationRecord
  #     include ThreadDecorators
  #
  #     # Delete the record asynchronously
  #     def adelete(...)
  #       delete(...)
  #     end
  #     async :
  #
  #     # Destroy the record asynchronously
  #     async def adestroy(...)
  #       destroy(...)
  #     end
  #
  #   end
  def_decorator :async do |func|
    Thread.new { func.call }
  end

  # Decorate the method to memoize in a Thread-local variable
  #
  # @example
  #   class SessionHelper
  #     include ThreadDecorators
  #
  #     # @return [String] a UUID
  #     @thread_local_cache >> :session_uuid
  #     def session_uuid
  #       SecureRandom.uuid
  #     end
  #   end
  def_decorator_factory :thread_local_cache do |var_name|
    ->(func) { Thread.current[var_name] ||= func.call }
  end
end
