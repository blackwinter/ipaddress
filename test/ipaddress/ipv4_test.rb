require 'test_helper'

class IPv4Test < Test::Unit::TestCase

  def setup
    @klass = IPAddress::IPv4

    @valid_ipv4 = {
      '0.0.0.0/0'              => ['0.0.0.0',  0],
      '10.0.0.0'               => ['10.0.0.0', 32],
      '10.0.0.1'               => ['10.0.0.1', 32],
      '10.0.0.1/24'            => ['10.0.0.1', 24],
      '10.0.0.1/255.255.255.0' => ['10.0.0.1', 24]
    }

    @invalid_ipv4 = %w[10.0.0.256 10.0.0.0.0 10.0.0 10.0 2001:db8::8:800:200c:417a]

    @valid_ipv4_range = %w[10.0.0.1-254 10.0.1-254.0 10.1-254.0.0]

    @netmask_values = {
      '0.0.0.0/0'        => '0.0.0.0',
      '10.0.0.0/8'       => '255.0.0.0',
      '172.16.0.0/16'    => '255.255.0.0',
      '192.168.0.0/24'   => '255.255.255.0',
      '192.168.100.4/30' => '255.255.255.252'
    }

    @decimal_values = {
      '0.0.0.0/0'        => 0,
      '10.0.0.0/8'       => 167772160,
      '172.16.0.0/16'    => 2886729728,
      '192.168.0.0/24'   => 3232235520,
      '192.168.100.4/30' => 3232261124
    }

    @ip      = @klass.new('172.16.10.1/24')
    @network = @klass.new('172.16.10.0/24')

    @broadcast = {
      '10.0.0.0/8'       => '10.255.255.255/8',
      '172.16.0.0/16'    => '172.16.255.255/16',
      '192.168.0.0/24'   => '192.168.0.255/24',
      '192.168.100.4/30' => '192.168.100.7/30'
    }

    @networks = {
      '10.5.4.3/8'       => '10.0.0.0/8',
      '172.16.5.4/16'    => '172.16.0.0/16',
      '192.168.4.3/24'   => '192.168.4.0/24',
      '192.168.100.5/30' => '192.168.100.4/30'
    }

    @class_a = @klass.new('10.0.0.1/8')
    @class_b = @klass.new('172.16.0.1/16')
    @class_c = @klass.new('192.168.0.1/24')

    @classful = {
      '10.1.1.1'  => 8,
      '150.1.1.1' => 16,
      '200.1.1.1' => 24
    }
  end

  def test_initialize
    @valid_ipv4.each_key { |i| assert_instance_of @klass, @klass.new(i) }
    assert_instance_of IPAddress::Prefix32, @ip.prefix
  end

  def test_initialize_format_error
    @invalid_ipv4.each { |i| assert_raise(ArgumentError) { @klass.new(i) } }
    assert_raise(ArgumentError) { @klass.new('10.0.0.0/asd') }
  end

  def test_initialize_without_prefix
    ip = @klass.new('10.10.0.0')
    assert_instance_of IPAddress::Prefix32, ip.prefix
    assert_equal 32, ip.prefix.prefix
  end

  def test_attributes
    @valid_ipv4.each { |arg, attr|
      ip = @klass.new(arg)
      assert_equal attr.first, ip.address
      assert_equal attr.last,  ip.prefix.prefix
    }
  end

  def test_octets
    assert_equal [10, 1, 2, 3], @klass.new('10.1.2.3/8').octets
  end

  def test_initialize_should_require_ip
    assert_raise(ArgumentError) { @klass.new }
  end

  def test_method_data
    assert_equal "\254\020\n\001", @ip.data
  end

  def test_method_to_string
    @valid_ipv4.each { |arg, attr|
      assert_equal attr.join('/'), @klass.new(arg).to_string
    }
  end

  def test_method_to_s
    @valid_ipv4.each { |arg, attr|
      assert_equal attr.first, @klass.new(arg).to_s
    }
  end

  def test_netmask
    @netmask_values.each { |addr, mask|
      assert_equal mask, @klass.new(addr).netmask
    }
  end

  def test_method_to_u32
    @decimal_values.each { |addr, int|
      ip = @klass.new(addr)
      assert_equal int, ip.to_u32
      assert_equal int, ip.to_i
    }
  end

  def test_method_network?
    assert @network.network?
    refute @ip.network?
  end

  def test_method_broadcast
    @broadcast.each { |addr, bcast|
      ip = @klass.new(addr)
      assert_instance_of @klass, ip.broadcast
      assert_equal bcast, ip.broadcast.to_string
    }
  end

  def test_method_network
    @networks.each { |addr, net|
      ip = @klass.new addr
      assert_instance_of @klass, ip.network
      assert_equal net, ip.network.to_string
    }
  end

  def test_method_bits
    ip = @klass.new('127.0.0.1')
    assert_equal '01111111000000000000000000000001', ip.bits
  end

  def test_method_first
    ip = @klass.new('192.168.100.0/24')
    assert_instance_of @klass, ip.first
    assert_equal '192.168.100.1', ip.first.to_s

    ip = @klass.new('192.168.100.50/24')
    assert_instance_of @klass, ip.first
    assert_equal '192.168.100.1', ip.first.to_s
  end

  def test_method_last
    ip = @klass.new('192.168.100.0/24')
    assert_instance_of @klass, ip.last
    assert_equal '192.168.100.254', ip.last.to_s

    ip = @klass.new('192.168.100.50/24')
    assert_instance_of @klass, ip.last
    assert_equal '192.168.100.254', ip.last.to_s
  end

  def test_method_each_host
    ary = []
    @klass.new('10.0.0.1/29').each_host { |i| ary << i.to_s }

    assert_equal %w[
      10.0.0.1 10.0.0.2 10.0.0.3
      10.0.0.4 10.0.0.5 10.0.0.6
    ], ary
  end

  def test_method_each
    ary = []
    @klass.new('10.0.0.1/29').each { |i| ary << i.to_s }

    assert_equal %w[
      10.0.0.0 10.0.0.1 10.0.0.2
      10.0.0.3 10.0.0.4 10.0.0.5
      10.0.0.6 10.0.0.7
    ], ary
  end

  def test_method_size
    assert_equal 8, @klass.new('10.0.0.1/29').size
  end

  def test_method_hosts
    assert_equal %w[
      10.0.0.1 10.0.0.2 10.0.0.3
      10.0.0.4 10.0.0.5 10.0.0.6
    ], @klass.new('10.0.0.1/29').hosts.map { |i| i.to_s }
  end

  def test_method_network_u32
    assert_equal 2886732288, @ip.network_u32
    assert_equal 2886732288, @ip.network_i
  end

  def test_method_broadcast_u32
    assert_equal 2886732543, @ip.broadcast_u32
    assert_equal 2886732543, @ip.broadcast_i
  end

  def test_method_include?
    ip = @klass.new('192.168.10.100/24')
    assert ip.include?(@klass.new('192.168.10.102/24'))
    refute ip.include?(@klass.new('172.16.0.48'))

    ip = @klass.new('10.0.0.0/8')
    assert ip.include?(@klass.new('10.0.0.0/9'))
    assert ip.include?(@klass.new('10.1.1.1/32'))
    assert ip.include?(@klass.new('10.1.1.1/9'))
    refute ip.include?(@klass.new('172.16.0.0/16'))
    refute ip.include?(@klass.new('10.0.0.0/7'))
    refute ip.include?(@klass.new('5.5.5.5/32'))
    refute ip.include?(@klass.new('11.0.0.0/8'))

    ip = @klass.new('13.13.0.0/13')
    refute ip.include?(@klass.new('13.16.0.0/32'))
  end

  def test_method_include_all?
    ip = @klass.new('192.168.10.100/24')
    addr1 = @klass.new('192.168.10.102/24')
    addr2 = @klass.new('192.168.10.103/24')

    assert ip.include_all?(addr1, addr2)
    refute ip.include_all?(addr1, @klass.new('13.16.0.0/32'))
  end

  def test_method_ipv4?
    assert @ip.ipv4?
  end

  def test_method_ipv6?
    refute @ip.ipv6?
  end

  def test_method_private?
    %w[
      192.168.10.50/24 192.168.10.50/16 172.16.77.40/24
      172.16.10.50/14 10.10.10.10/10 10.0.0.0/8
    ].each { |i| assert @klass.new(i).private? }

    %w[
      192.168.10.50/12 3.3.3.3 10.0.0.0/7
      172.32.0.0/12 172.16.0.0/11 192.0.0.2/24
    ].each { |i| refute @klass.new(i).private? }
  end

  def test_method_octet
    assert_equal 172, @ip[0]
    assert_equal 16,  @ip[1]
    assert_equal 10,  @ip[2]
    assert_equal 1,   @ip[3]
  end

  def test_method_a?
    assert @class_a.a?
    refute @class_b.a?
    refute @class_c.a?
  end

  def test_method_b?
    assert @class_b.b?
    refute @class_a.b?
    refute @class_c.b?
  end

  def test_method_c?
    assert @class_c.c?
    refute @class_a.c?
    refute @class_b.c?
  end

  def test_method_to_ipv6
    assert_equal 'ac10:0a01', @ip.to_ipv6
  end

  def test_method_reverse
    assert_equal '1.10.16.172.in-addr.arpa', @ip.reverse
  end

  def test_method_compare
    ip1 = @klass.new('10.1.1.1/8')
    ip2 = @klass.new('10.1.1.1/16')
    ip3 = @klass.new('172.16.1.1/14')
    ip4 = @klass.new('10.1.1.1/8')

    assert ip1 < ip2
    refute ip1 > ip2
    refute ip2 < ip1
    assert ip2 < ip3
    refute ip2 > ip3
    assert ip1 < ip3
    refute ip1 > ip3
    refute ip3 < ip1
    assert ip1 == ip1
    assert ip1 == ip4

    ary = %w[10.1.1.1/8 10.1.1.1/16 172.16.1.1/14]
    assert_equal_ary ary, [ip1, ip2, ip3].sort

    ip1 = @klass.new('10.0.0.0/24')
    ip2 = @klass.new('10.0.0.0/16')
    ip3 = @klass.new('10.0.0.0/8')
    ary = %w[10.0.0.0/8 10.0.0.0/16 10.0.0.0/24]
    assert_equal_ary ary, [ip1, ip2, ip3].sort
  end

  def test_method_distance
    ip1 = @klass.new('10.1.1.1/8')
    ip2 = @klass.new('10.1.1.10/8')
    assert_equal 9, ip2.distance(ip1)
    assert_equal 9, ip1.distance(ip2)
  end

  def test_method_plus
    ip1 = @klass.new('172.16.10.1/24')
    ip2 = @klass.new('172.16.11.2/24')
    assert_equal_ary %w[172.16.10.0/23], ip1 + ip2

    ip2 = @klass.new('172.16.12.2/24')
    assert_equal_ary [ip1.network.to_string, ip2.network.to_string], ip1 + ip2

    ip1 = @klass.new('10.0.0.0/23')
    ip2 = @klass.new('10.0.2.0/24')
    assert_equal_ary %w[10.0.0.0/23 10.0.2.0/24], ip1 + ip2

    ip1 = @klass.new('10.0.0.0/23')
    ip2 = @klass.new('10.0.2.0/24')
    assert_equal_ary %w[10.0.0.0/23 10.0.2.0/24], ip2 + ip1

    ip1 = @klass.new('10.0.0.0/16')
    ip2 = @klass.new('10.0.2.0/24')
    assert_equal_ary %w[10.0.0.0/16], ip1 + ip2

    ip1 = @klass.new('10.0.0.0/23')
    ip2 = @klass.new('10.1.0.0/24')
    assert_equal_ary %w[10.0.0.0/23 10.1.0.0/24], ip1 + ip2
  end

  def test_method_netmask_equal
    ip = @klass.new('10.1.1.1/16')
    assert_equal 16, ip.prefix.prefix
    assert_raise(NoMethodError) { ip.netmask = '255.255.255.0' }

    ip2 = ip.new_netmask('255.255.255.0')
    assert_equal 16, ip.prefix.prefix
    assert_equal 24, ip2.prefix.prefix
  end

  def test_method_split
    assert_raise(ArgumentError) { @ip.split(0) }
    assert_raise(ArgumentError) { @ip.split(257) }

    assert_equal @ip.network, @ip.split(1).first

    {
      8 => %w[
        172.16.10.0/27 172.16.10.32/27 172.16.10.64/27
        172.16.10.96/27 172.16.10.128/27 172.16.10.160/27
        172.16.10.192/27 172.16.10.224/27
      ],
      7 => %w[
        172.16.10.0/27 172.16.10.32/27 172.16.10.64/27
        172.16.10.96/27 172.16.10.128/27 172.16.10.160/27
        172.16.10.192/26
      ],
      6 => %w[
        172.16.10.0/27 172.16.10.32/27 172.16.10.64/27
        172.16.10.96/27 172.16.10.128/26 172.16.10.192/26
      ],
      5 => %w[
        172.16.10.0/27 172.16.10.32/27 172.16.10.64/27
        172.16.10.96/27 172.16.10.128/25
      ],
      4 => %w[
        172.16.10.0/26 172.16.10.64/26 172.16.10.128/26
        172.16.10.192/26
      ],
      3 => %w[
        172.16.10.0/26 172.16.10.64/26 172.16.10.128/25
      ],
      2 => %w[
        172.16.10.0/25 172.16.10.128/25
      ],
      1 => %w[
        172.16.10.0/24
      ]
    }.each { |i, a| assert_equal_ary a, @network.split(i) }
  end

  def test_method_subnet
    assert_raise(ArgumentError) { @network.subnet(23) }
    assert_raise(ArgumentError) { @network.subnet(33) }

    {
      26 => %w[
        172.16.10.0/26 172.16.10.64/26 172.16.10.128/26
        172.16.10.192/26
      ],
      25 => %w[
        172.16.10.0/25 172.16.10.128/25
      ],
      24 => %w[
        172.16.10.0/24
      ]
    }.each { |i, a| assert_equal_ary a, @network.subnet(i) }
  end

  def test_method_supernet
    assert_raise(ArgumentError) { @ip.supernet(24) }

    {
       0 => '0.0.0.0/0',
      -2 => '0.0.0.0/0',
      23 => '172.16.10.0/23',
      22 => '172.16.8.0/22'
    }.each { |i, s| assert_equal s, @ip.supernet(i).to_string }
  end

  def test_classmethod_parse_u32
    @decimal_values.each { |addr, int|
      ip = @klass.parse_u32(int, addr.split('/').last.to_i)
      assert_equal ip.to_string, addr
    }
  end

  def test_classmethod_extract
    str = 'foobar172.16.10.1barbaz1.2.3.4/24'
    assert_equal '172.16.10.1/32', @klass.extract(str).to_string
  end

  def test_classmethod_extract_all
    str = 'foobar172.16.10.1barbaz1.2.3.4/24'
    assert_equal_ary %w[172.16.10.1/32 1.2.3.4/32], @klass.extract_all(str)
  end

  def test_classmethod_summarize
    assert_equal [@ip.network], @klass.summarize(@ip)

    # Summarize homogeneous networks
    assert_equal_ary %w[172.16.10.0/23], @klass.summarize(
      @klass.new('172.16.10.1/24'), @klass.new('172.16.11.2/24')
    )

    ips = [
      @klass.new('10.0.0.1/24'), @klass.new('10.0.1.1/24'),
      @klass.new('10.0.2.1/24'), @klass.new('10.0.3.1/24')
    ]
    assert_equal_ary %w[10.0.0.0/22], @klass.summarize(*ips)
    assert_equal_ary %w[10.0.0.0/22], @klass.summarize(*ips.reverse)

    # Summarize non homogeneous networks
    assert_equal_ary %w[10.0.0.0/23 10.0.2.0/24], @klass.summarize(
      @klass.new('10.0.0.0/23'), @klass.new('10.0.2.0/24')
    )

    assert_equal_ary %w[10.0.0.0/16], @klass.summarize(
      @klass.new('10.0.0.0/16'), @klass.new('10.0.2.0/24')
    )

    assert_equal_ary %w[10.0.0.0/23 10.1.0.0/24], @klass.summarize(
      @klass.new('10.0.0.0/23'), @klass.new('10.1.0.0/24')
    )

    assert_equal_ary %w[10.0.0.0/22 10.0.4.0/24 10.0.6.0/24], @klass.summarize(
      @klass.new('10.0.0.0/23'), @klass.new('10.0.2.0/23'),
      @klass.new('10.0.4.0/24'), @klass.new('10.0.6.0/24')
    )

    res, ips = %w[10.0.1.0/24 10.0.2.0/23 10.0.4.0/24], [
      @klass.new('10.0.1.1/24'), @klass.new('10.0.2.1/24'),
      @klass.new('10.0.3.1/24'), @klass.new('10.0.4.1/24')
    ]
    assert_equal_ary res, @klass.summarize(*ips)
    assert_equal_ary res, @klass.summarize(*ips.reverse)

    assert_equal_ary %w[10.0.1.0/24 10.10.2.0/24 172.16.0.0/23], @klass.summarize(
      @klass.new('10.0.1.1/24'),   @klass.new('10.10.2.1/24'),
      @klass.new('172.16.0.1/24'), @klass.new('172.16.1.1/24')
    )

    assert_equal_ary %w[10.0.0.12/30 10.0.100.0/24], @klass.summarize(
      @klass.new('10.0.0.12/30'), @klass.new('10.0.100.0/24')
    )

    assert_equal_ary %w[10.10.2.1/32 172.16.0.0/31], @klass.summarize(
      @klass.new('172.16.0.0/31'), @klass.new('10.10.2.1/32')
    )

    assert_equal_ary %w[10.10.2.1/32 172.16.0.0/32], @klass.summarize(
      @klass.new('172.16.0.0/32'), @klass.new('10.10.2.1/32')
    )
  end

  def test_classmethod_parse_data
    ip = @klass.parse_data("\254\020\n\001")
    assert_instance_of @klass, ip
    assert_equal '172.16.10.1',    ip.to_s
    assert_equal '172.16.10.1/32', ip.to_string
  end

  def test_classmethod_parse_classful
    @classful.each { |ip, prefix|
      res = @klass.parse_classful(ip)
      assert_equal prefix, res.prefix.prefix
      assert_equal "#{ip}/#{prefix}", res.to_string
    }

    assert_raise(ArgumentError) { @klass.parse_classful('192.168.256.257') }
  end

end
