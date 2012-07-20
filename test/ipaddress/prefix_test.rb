require 'test_helper'

class Prefix32Test < Test::Unit::TestCase

  def setup
    @netmasks = [
      @netmask0  = '0.0.0.0',
      @netmask8  = '255.0.0.0',
      @netmask16 = '255.255.0.0',
      @netmask24 = '255.255.255.0',
      @netmask30 = '255.255.255.252'
    ]

    @prefix_hash = {
      '0.0.0.0'         => 0,
      '255.0.0.0'       => 8,
      '255.255.0.0'     => 16,
      '255.255.255.0'   => 24,
      '255.255.255.252' => 30
    }

    @octets_hash = {
      [0,   0,   0,   0]   => 0,
      [255, 0,   0,   0]   => 8,
      [255, 255, 0,   0]   => 16,
      [255, 255, 255, 0]   => 24,
      [255, 255, 255, 252] => 30
    }

    @u32_hash = {
      0  => 0,
      8  => 4278190080,
      16 => 4294901760,
      24 => 4294967040,
      30 => 4294967292
    }

    @klass = IPAddress::Prefix32
  end

  def test_attributes
    @prefix_hash.each_value { |num|
      assert_equal num, @klass.new(num).prefix
    }
  end

  def test_parse_netmask
    @prefix_hash.each { |netmask, num|
      prefix = @klass.parse_netmask(netmask)
      assert_equal num, prefix.prefix
      assert_instance_of @klass, prefix
    }
  end

  def test_method_to_ip
    @prefix_hash.each { |netmask, num|
      assert_equal netmask, @klass.new(num).to_ip
    }
  end

  def test_method_to_s
    @prefix_hash.each_value { |num|
      assert_equal num.to_s, @klass.new(num).to_s
    }
  end

  def test_method_bits
    assert_equal '1' * 16 << '0' * 16, @klass.new(16).bits
  end

  def test_method_to_u32
    @u32_hash.each { |num, u32|
      prefix = @klass.new(num)
      assert_equal u32, prefix.to_u32
      assert_equal u32, prefix.to_i
    }
  end

  def test_method_plus
    p1 = @klass.new(8)
    p2 = @klass.new(10)
    assert_equal 18, p1 + p2
    assert_equal 12, p1 + 4
  end

  def test_method_minus
    p1 = @klass.new(8)
    p2 = @klass.new(24)
    assert_equal 16, p1 - p2
    assert_equal 16, p2 - p1
    assert_equal 20, p2 - 4
  end

  def test_initialize
    assert_raise(ArgumentError) { @klass.new(33) }
    assert_instance_of @klass, @klass.new(8)
  end

  def test_method_octets
    @octets_hash.each { |ary, pref|
      assert_equal ary, @klass.new(pref).octets
    }
  end

  def test_method_brackets
    @octets_hash.each { |ary, pref|
      prefix = @klass.new(pref)
      ary.each_with_index { |oct, index|
        assert_equal oct, prefix[index]
      }
    }
  end

  def test_method_hostmask
    assert_equal '0.255.255.255', @klass.new(8).hostmask
  end

end

class Prefix128Test < Test::Unit::TestCase

  def setup
    @u128_hash = {
      32  => 340282366841710300949110269838224261120,
      64  => 340282366920938463444927863358058659840,
      96  => 340282366920938463463374607427473244160,
      126 => 340282366920938463463374607431768211452
    }

    @klass = IPAddress::Prefix128
  end

  def test_initialize
    assert_raise(ArgumentError) { @klass.new(129) }
    assert_instance_of @klass, @klass.new(64)
  end

  def test_method_bits
    assert_equal '1' * 64 << '0' * 64, @klass.new(64).bits
  end

  def test_method_to_u32
    @u128_hash.each { |num, u128|
      prefix = @klass.new(num)
      assert_equal u128, prefix.to_u128
      assert_equal u128, prefix.to_i
    }
  end

end
