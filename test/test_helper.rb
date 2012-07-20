require 'test/unit'
require 'ipaddress'

class Test::Unit::TestCase

  if RUBY_VERSION < '1.9'
    def refute(test, *args)
      !assert(!test, *args)
    end
  end

  def assert_equal_ary(exp, act, *args)
    assert_equal(exp, act.map { |i| i.to_string }, *args)
  end

end
