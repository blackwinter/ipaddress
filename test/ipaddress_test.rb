require 'test_helper'

class IPAddressTest < Test::Unit::TestCase

  def test_method_IPAddress
    {
      '172.16.10.1/24'               => IPAddress::IPv4,
      '2001:db8::8:800:200c:417a/64' => IPAddress::IPv6,
      '::13.1.68.3'                  => IPAddress::IPv6::Mapped
    }.each { |i, c| assert_instance_of c, IPAddress(i) }

    %w[10.0.0.256 :1:2:3:4:5:6:7 ::1:2.3.4 1234].each { |i|
      assert_raise(ArgumentError) { IPAddress(i) }
    }
  end

  def test_classmethod_valid?
    assert IPAddress.valid?('10.0.0.1')
    assert IPAddress.valid?('10.0.0.0')
    assert IPAddress.valid?('2002::1')
    assert IPAddress.valid?('dead:beef:cafe:babe::f0ad')
    refute IPAddress.valid?('10.0.0.256')
    refute IPAddress.valid?('10.0.0.0.0')
    refute IPAddress.valid?('10.0.0')
    refute IPAddress.valid?('10.0')
    refute IPAddress.valid?('2002:::1')
  end

  def test_classmethod_valid_ipv4_netmask?
    assert IPAddress.valid_ipv4_netmask?('255.255.255.0')
    refute IPAddress.valid_ipv4_netmask?('10.0.0.1')
  end

  def test_classmethod_parse_i
    [
      [IPAddress::IPv4,         '172.16.10.1/32',                4, 2886732289],
      [IPAddress::IPv4,         '172.16.10.1/24',                4, 2886732289, 24],
      [IPAddress::IPv6,         '2001:db8::8:800:200c:417a/128', 6, 42540766411282592856906245548098208122],
      [IPAddress::IPv6,         '2001:db8::8:800:200c:417a/64',  6, 42540766411282592856906245548098208122, 64],
      [IPAddress::IPv6::Mapped, '::ffff:13.1.68.3/128',          6, 281470899930115],
      [IPAddress::IPv6::Mapped, '::ffff:13.1.68.3/48',           6, 281470899930115, 48]
    ].each { |c, s, *a|
      ip = IPAddress.parse_i(*a)
      assert_instance_of c, ip
      assert_equal s, ip.to_string
    }

    assert_raise(ArgumentError) { IPAddress.parse_i(0, 0) }
  end

  def test_classmethod_summarize_ipv4
    # TODO
  end

  def test_classmethod_summarize_ipv6
    # TODO
  end

  def test_classmethod_summarize_ipv4_and_ipv6
    # TODO
  end

  def test_classmethod_subtract
    # TODO
  end

  def test_method_include_exactly?
    # TODO
  end

  def test_method_overlap?
    # TODO
  end

  def test_method_exact_supernet
    # TODO
  end

  def test_method_proper_supernet
    # TODO
  end

  def test_method_subtract
    # TODO
  end

  def test_method_summarize
    # TODO
  end

  def test_method_range
    # TODO
  end

  def test_method_boundaries
    # TODO
  end

  def test_method_each_i
    # TODO
  end

  def test_method_at
    # TODO
  end

  def test_method_mapped
    # TODO
  end

  def test_method_hash
    ips = [
      IPAddress('1.2.3.4/24'), IPAddress('2.4.6.8/32'),
      IPAddress('1.2.3.4/24'), IPAddress('2.4.6.8/31')
    ]

    require 'set'
    h, s = {}, Set.new

    ips.each_with_index { |i, j|
      h[i] = j
      s << i
    }

    assert ips[0] == ips[2]
    refute ips[0] == ips[1]

    assert ips[0].eql?(ips[2])
    refute ips[0].eql?(ips[1])

    assert_equal     ips[0].hash, ips[2].hash
    assert_not_equal ips[0].hash, ips[1].hash

    assert_equal ips.values_at(0, 3, 1), h.keys.sort
    assert_equal ips.values_at(0, 3, 1), s.to_a.sort
    assert_equal ips.values_at(0, 1, 3), ips.uniq
  end

end
