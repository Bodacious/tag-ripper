# frozen_string_literal: true

require "some_file"

# Foo module
# @domain: Fizz
# @domain: Buzz
module Foo
  # Bar class
  # @domain: FooDomain
  class Bar

    # @domain: Method
    def method_a; end

    private

    # This is a private method
    # @domain: PrivMethod
    def method_b; end
  end
end
