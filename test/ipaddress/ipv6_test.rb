require 'test_helper'

class IPv6Test < Test::Unit::TestCase

  def setup
    @klass = IPAddress::IPv6

    @compress_addr = {
      '2001:db8:0000:0000:0008:0800:200c:417a' => '2001:db8::8:800:200c:417a',
      '2001:db8:0:0:8:800:200c:417a'           => '2001:db8::8:800:200c:417a',
      'ff01:0:0:0:0:0:0:101'                   => 'ff01::101',
      '0:0:0:0:0:0:0:1'                        => '::1',
      '0:0:0:0:0:0:0:0'                        => '::'
    }

    @valid_ipv6 = {
      'FEDC:BA98:7654:3210:FEDC:BA98:7654:3210' => 338770000845734292534325025077361652240,
      '1080:0000:0000:0000:0008:0800:200C:417A' => 21932261930451111902915077091070067066,
      '1080:0:0:0:8:800:200C:417A'              => 21932261930451111902915077091070067066,
      '1080:0::8:800:200C:417A'                 => 21932261930451111902915077091070067066,
      '1080::8:800:200C:417A'                   => 21932261930451111902915077091070067066,
      'FF01:0:0:0:0:0:0:43'                     => 338958331222012082418099330867817087043,
      'FF01:0:0::0:0:43'                        => 338958331222012082418099330867817087043,
      'FF01::43'                                => 338958331222012082418099330867817087043,
      '0:0:0:0:0:0:0:1'                         => 1,
      '0:0:0::0:0:1'                            => 1,
      '::1'                                     => 1,
      '0:0:0:0:0:0:0:0'                         => 0,
      '0:0:0::0:0:0'                            => 0,
      '::'                                      => 0,
      '1080:0:0:0:8:800:200C:417A'              => 21932261930451111902915077091070067066,
      '1080::8:800:200C:417A'                   => 21932261930451111902915077091070067066
    }

    @invalid_ipv6 = %w[:1:2:3:4:5:6:7 :1:2:3:4:5:6:7 ::10.1.1.1 172.16.10.1]

    @networks = {
      '2001:db8:1:1:1:1:1:1/32' => '2001:db8::/32',
      '2001:db8:1:1:1:1:1::/32' => '2001:db8::/32',
      '2001:db8::1/64'          => '2001:db8::/64'
    }

    @ip      = @klass.new('2001:db8::8:800:200c:417a/64')
    @network = @klass.new('2001:db8:8:800::/64')

    @ary = [8193, 3512, 0, 0, 8, 2048, 8204, 16762]
    @hex = '20010db80000000000080800200c417a'
  end

  def test_attribute_address
    assert_equal '2001:0db8:0000:0000:0008:0800:200c:417a', @ip.address
  end

  def test_initialize
    assert_instance_of @klass, @ip
    assert_equal 64, @ip.prefix.prefix

    @invalid_ipv6.each { |i| assert_raise(ArgumentError) { @klass.new(i) } }
  end

  def test_attribute_groups
    assert_equal @ary, @ip.groups
  end

  def test_method_hexs
    assert_equal '2001:0db8:0000:0000:0008:0800:200c:417a'.split(':'), @ip.hexs
  end

  def test_method_to_i
    @valid_ipv6.each { |ip, num| assert_equal num, @klass.new(ip).to_i }
  end

  def test_method_bits
    bits = '0010000000000001000011011011100000000000000000000' +
      '000000000000000000000000000100000001000000000000010000' +
      '0000011000100000101111010'
    assert_equal bits, @ip.bits
  end

  def test_method_prefix=
    ip = @klass.new('2001:db8::8:800:200c:417a')
    assert_equal 128, ip.prefix.prefix

    ip2 = ip.new_prefix(64)
    assert_equal 128, ip.prefix.prefix
    assert_equal 64, ip2.prefix.prefix
    assert_equal '2001:db8::8:800:200c:417a/64', ip2.to_string
  end

  def test_method_mapped?
    refute @ip.mapped?
    assert @klass.new('::ffff:1234:5678').mapped?
  end

  def test_method_literal
    str = '2001-0db8-0000-0000-0008-0800-200c-417a.ipv6-literal.net'
    assert_equal str, @ip.literal
  end

  def test_method_group
    @ary.each_with_index { |val, index| assert_equal val, @ip[index] }
  end

  def test_method_ipv4?
    refute @ip.ipv4?
  end

  def test_method_ipv6?
    assert @ip.ipv6?
  end

  def test_method_network?
    assert @network.network?
    refute @ip.network?
  end

  def test_method_network_u128
    i = 42540766411282592856903984951653826560
    assert_equal i, @ip.network_u128
    assert_equal i, @ip.network_i
  end

  def test_method_broadcast_u128
    i = 42540766411282592875350729025363378175
    assert_equal i, @ip.broadcast_u128
    assert_equal i, @ip.broadcast_i
  end

  def test_method_size
    {
      '2001:db8::8:800:200c:417a/64'  => 64,
      '2001:db8::8:800:200c:417a/32'  => 96,
      '2001:db8::8:800:200c:417a/120' => 8,
      '2001:db8::8:800:200c:417a/124' => 4
    }.each { |i, s| assert_equal 2 ** s, @klass.new(i).size }
  end

  def test_method_include?
    assert @ip.include?(@ip)

    # test prefix on same address
    assert @ip.include?(@klass.new('2001:db8::8:800:200c:417a/128'))
    refute @ip.include?(@klass.new('2001:db8::8:800:200c:417a/46'))

    # test address on same prefix
    assert @ip.include?(@klass.new('2001:db8::8:800:200c:0/64'))
    refute @ip.include?(@klass.new('2001:db8:1::8:800:200c:417a/64'))

    # general test
    assert @ip.include?(@klass.new('2001:db8::8:800:200c:1/128'))
    refute @ip.include?(@klass.new('2001:db8:1::8:800:200c:417a/76'))
  end

  def test_method_to_hex
    assert_equal @hex, @ip.to_hex
  end

  def test_method_to_s
    assert_equal '2001:db8::8:800:200c:417a', @ip.to_s
  end

  def test_method_to_string
    assert_equal '2001:db8::8:800:200c:417a/64', @ip.to_string
  end

  def test_method_to_string_uncompressed
    str = '2001:0db8:0000:0000:0008:0800:200c:417a/64'
    assert_equal str, @ip.to_string_uncompressed
  end

  def test_method_data
    str = " \001\r\270\000\000\000\000\000\b\b\000 \fAz"
    assert_equal str, @ip.data
  end

  def test_method_reverse
    str = 'f.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.2.0.0.0.5.0.5.0.e.f.f.3.ip6.arpa'
    assert_equal str, @klass.new('3ffe:505:2::f').reverse
  end

  def test_method_compressed
    {
      '1:1:1:0:0:0:0:1' => '1:1:1::1',
      '1:0:1:0:0:0:0:1' => '1:0:1::1',
      '1:0:0:1:0:0:0:1' => '1:0:0:1::1',
      '1:0:0:0:1:0:0:1' => '1::1:0:0:1',
      '1:0:0:0:0:0:0:1' => '1::1'
    }.each { |i, c| assert_equal c, @klass.new(i).compressed }
  end

  def test_method_unspecified?
    assert @klass.new('::').unspecified?
    refute @ip.unspecified?
  end

  def test_method_loopback?
    assert @klass.new('::1').loopback?
    refute @ip.loopback?
  end

  def test_method_network
    @networks.each { |addr, net|
      ip = @klass.new(addr)
      assert_instance_of @klass, ip.network
      assert_equal net, ip.network.to_string
    }
  end

  def test_method_each
    ary = []
    @klass.new('2001:db8::4/125').each { |i| ary << i.compressed }

    assert_equal %w[
      2001:db8:: 2001:db8::1 2001:db8::2
      2001:db8::3 2001:db8::4 2001:db8::5
      2001:db8::6 2001:db8::7
    ], ary
  end

  def test_method_compare
    ip1 = @klass.new('2001:db8:1::1/64')
    ip2 = @klass.new('2001:db8:2::1/64')
    ip3 = @klass.new('2001:db8:1::2/64')
    ip4 = @klass.new('2001:db8:1::1/65')

    assert ip2 > ip1
    refute ip1 > ip2
    refute ip2 < ip1
    assert ip2 > ip3
    refute ip2 < ip3
    assert ip1 < ip3
    refute ip1 > ip3
    refute ip3 < ip1
    assert ip1 == ip1
    assert ip1 < ip4
    refute ip1 > ip4

    assert_equal_ary %w[
      2001:db8:1::1/64 2001:db8:1::1/65
      2001:db8:1::2/64 2001:db8:2::1/64
    ], [ip1, ip2, ip3, ip4].sort
  end

  def test_classmethod_expand
    expanded = '2001:0db8:0000:cd30:0000:0000:0000:0000'
    assert_equal     expanded, @klass.expand('2001:db8:0:cd30::')
    assert_not_equal expanded, @klass.expand('2001:0db8:0:cd3')
    assert_not_equal expanded, @klass.expand('2001:0db8::cd30')
    assert_not_equal expanded, @klass.expand('2001:0db8::cd3')
  end

  def test_classmethod_compress
    compressed = '2001:db8:0:cd30::'
    assert_equal     compressed, @klass.compress('2001:0db8:0000:cd30:0000:0000:0000:0000')
    assert_not_equal compressed, @klass.compress('2001:0db8:0:cd3')
    assert_not_equal compressed, @klass.compress('2001:0db8::cd30')
    assert_not_equal compressed, @klass.compress('2001:0db8::cd3')
  end

  def test_classmethod_parse_data
    ip = @klass.parse_data(" \001\r\270\000\000\000\000\000\b\b\000 \fAz")
    assert_instance_of @klass, ip
    assert_equal '2001:0db8:0000:0000:0008:0800:200c:417a', ip.address
    assert_equal '2001:db8::8:800:200c:417a/128', ip.to_string
  end

  def test_classhmethod_parse_u128
    @valid_ipv6.each { |ip, num|
      i = @klass.new(ip).to_string
      assert_equal i, @klass.parse_u128(num).to_string
      assert_equal i, @klass.parse_i(num).to_string
    }
  end

  def test_classmethod_parse_hex
    assert_equal @ip.to_string, @klass.parse_hex(@hex, 64).to_string
  end

end

class IPv6UnspecifiedTest < Test::Unit::TestCase

  def setup
    @klass = IPAddress::IPv6::Unspecified
    @ip = @klass.new
  end

  def test_initialize
    assert_instance_of @klass, @ip
  end

  def test_attributes
    assert_equal '::', @ip.compressed
    assert_equal 128, @ip.prefix.prefix
    assert @ip.unspecified?
    assert_equal '::', @ip.to_s
    assert_equal '::/128', @ip.to_string
    assert_equal '0000:0000:0000:0000:0000:0000:0000:0000/128', @ip.to_string_uncompressed
    assert_equal 0, @ip.to_u128
  end

  def test_method_ipv4?
    refute @ip.ipv4?
  end

  def test_method_ipv6?
    assert @ip.ipv6?
  end

end

class IPv6LoopbackTest < Test::Unit::TestCase

  def setup
    @klass = IPAddress::IPv6::Loopback
    @ip = @klass.new
  end

  def test_initialize
    assert_instance_of @klass, @ip
  end

  def test_attributes
    assert_equal '::1', @ip.compressed
    assert_equal 128, @ip.prefix.prefix
    assert @ip.loopback?
    assert_equal '::1', @ip.to_s
    assert_equal '::1/128', @ip.to_string
    assert_equal '0000:0000:0000:0000:0000:0000:0000:0001/128', @ip.to_string_uncompressed
    assert_equal 1, @ip.to_u128
  end

  def test_method_ipv4?
    refute @ip.ipv4?
  end

  def test_method_ipv6?
    assert @ip.ipv6?
  end

end

class IPv6MappedTest < Test::Unit::TestCase

  def setup
    @klass = IPAddress::IPv6::Mapped
    @ip = @klass.new('::172.16.10.1')

    @valid_mapped = {
      '::13.1.68.3'                  => 281470899930115,
      '0:0:0:0:0:ffff:129.144.52.38' => 281472855454758,
      '::ffff:129.144.52.38'         => 281472855454758
    }

    @valid_mapped_ipv6 = {
      '::0d01:4403'              => 281470899930115,
      '0:0:0:0:0:ffff:8190:3426' => 281472855454758,
      '::ffff:8190:3426'         => 281472855454758
    }

    @valid_mapped_ipv6_conversion = {
      '::0d01:4403'              => '13.1.68.3',
      '0:0:0:0:0:ffff:8190:3426' => '129.144.52.38',
      '::ffff:8190:3426'         => '129.144.52.38'
    }
  end

  def test_initialize
    assert_instance_of @klass, @ip

    @valid_mapped.each { |ip, u128|
      assert_equal u128, @klass.new(ip).to_u128
      assert_equal u128, @klass.new(ip).to_i
    }

    @valid_mapped_ipv6.each { |ip, u128|
      assert_equal u128, @klass.new(ip).to_u128
      assert_equal u128, @klass.new(ip).to_i
    }
  end

  def test_mapped_from_ipv6_conversion
    @valid_mapped_ipv6_conversion.each { |ip6, ip4|
      assert_equal ip4, @klass.new(ip6).ipv4.to_s
    }
  end

  def test_attributes
    assert_equal '::ffff:ac10:a01', @ip.compressed
    assert_equal 128, @ip.prefix.prefix
    assert_equal '::ffff:172.16.10.1', @ip.to_s
    assert_equal '::ffff:172.16.10.1/128', @ip.to_string
    assert_equal '0000:0000:0000:0000:0000:ffff:ac10:0a01/128', @ip.to_string_uncompressed
    assert_equal 281473568475649, @ip.to_u128
  end

  def test_method_ipv4?
    refute @ip.ipv4?
  end

  def test_method_ipv6?
    assert @ip.ipv6?
  end

  def test_mapped?
    assert @ip.mapped?
  end

end
