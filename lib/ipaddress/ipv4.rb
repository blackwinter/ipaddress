class IPAddress

  #
  # =Name
  #
  # IPAddress::IPv4 - IP version 4 address manipulation library
  #
  # =Synopsis
  #
  #    require 'ipaddress'
  #
  # =Description
  #
  # Class IPAddress::IPv4 is used to handle IPv4 type addresses.
  #
  class IPv4 < self

    #
    # This Hash contains the prefix values for Classful networks
    #
    # Note that classes C, D and E will all have a default
    # prefix of /24 or 255.255.255.0
    #
    CLASSFUL = {
      8  => /\A0../,  # Class A, from 0.0.0.0 to 127.255.255.255
      16 => /\A10./,  # Class B, from 128.0.0.0 to 191.255.255.255
      24 => /\A110/   # Class C, D and E, from 192.0.0.0 to 255.255.255.254
    }

    part = %r{ (?: 25[0-5] | 2[0-4]\d | 1\d\d | [1-9]\d | \d ) }x

    INTERNAL_RE = %r{ (?: #{part} \. ){3} #{part} }xo

    #
    # Regular expression to match an IPv4 address
    #
    RE = %r{ \A #{INTERNAL_RE} \z }xo

    Prefix = Prefix32

    MAX_PREFIX = Prefix::MAX

    PREFIX_RE = %r{ \A (?: [12]?\d | 3[0-2] ) \z }x

    class << self

      alias_method :valid_ip?, :valid_ipv4?

      #
      # Creates a new IPv4 object from an
      # unsigned 32bits integer.
      #
      #   ip = IPAddress::IPv4.parse_u32(167772160)
      #
      #   ip.to_string
      #     #=> "10.0.0.0/32"
      #
      # The +prefix+ parameter is optional:
      #
      #   ip = IPAddress::IPv4.parse_u32(167772160, 8)
      #
      #   ip.to_string
      #     #=> "10.0.0.0/8"
      #
      def parse_i(i, prefix = MAX_PREFIX)
        instantiate { @int, @_prefix = i, prefix }
      end

      alias_method :parse_u32, :parse_i

      #
      # Creates a new IPv4 object from binary data,
      # like the one you get from a network stream.
      #
      # For example, on a network stream the IP 172.16.0.1
      # is represented with the binary "\254\020\n\001".
      #
      #   ip = IPAddress::IPv4.parse_data("\254\020\n\001", 24)
      #
      #   ip.to_string
      #     #=> "172.16.10.1/24"
      #
      def parse_data(data, prefix = MAX_PREFIX)
        parse_i(data2int(data), prefix)
      end

      #
      # Creates a new IPv4 address object by parsing the
      # address in a classful way.
      #
      # Classful addresses have a fixed netmask based on the
      # class they belong to:
      #
      # * Class A, from 0.0.0.0 to 127.255.255.255
      # * Class B, from 128.0.0.0 to 191.255.255.255
      # * Class C, D and E, from 192.0.0.0 to 255.255.255.254
      #
      # Example:
      #
      #   ip = IPAddress::IPv4.parse_classful("10.0.0.1")
      #
      #   ip.netmask
      #     #=> "255.0.0.0"
      #   ip.a?
      #     #=> true
      #
      # Note that classes C, D and E will all have a default
      # prefix of /24 or 255.255.255.0
      #
      def parse_classful(ip)
        raise ArgumentError, "Invalid IP #{ip.inspect}" unless valid_ipv4?(ip)

        bits = '%.8b' % ip.to_i
        new("#{ip.strip}/#{CLASSFUL.find { |_, re| re === bits }.first}")
      end

      #
      # Extract an IPv4 address from a string and
      # returns a new object
      #
      # Example:
      #
      #   str = "foobar172.16.10.1barbaz"
      #   ip = IPAddress::IPv4.extract(str)
      #
      #   ip.to_s
      #     #=> "172.16.10.1"
      #
      def extract(str, prefix = MAX_PREFIX)
        new("#{INTERNAL_RE.match(str)}/#{prefix}")
      end

      def extract_all(str, prefix = MAX_PREFIX)
        str.scan(INTERNAL_RE).map! { |m| new("#{m}/#{prefix}") }
      end

      def private_nets
        @private_nets ||= %w[
          10.0.0.0/8
          172.16.0.0/12
          192.168.0.0/16
        ].map! { |i| new(i) }
      end

    end

    #
    # Creates a new IPv4 address object.
    #
    # An IPv4 address can be expressed in any of the following forms:
    #
    # * "10.1.1.1/24": ip +address+ and +prefix+. This is the common and
    # suggested way to create an object.
    # * "10.1.1.1/255.255.255.0": ip +address+ and +netmask+. Although
    # convenient sometimes, this format is less clear than the previous
    # one.
    # * "10.1.1.1": if the address alone is specified, the prefix will be
    # set as default 32, also known as the host prefix
    #
    # Examples:
    #
    #   # These two are the same
    #   ip = IPAddress::IPv4.new("10.0.0.1/24")
    #   ip = IPAddress("10.0.0.1/24")
    #
    #   # These two are the same
    #   IPAddress::IPv4.new("10.0.0.1/8")
    #   IPAddress::IPv4.new("10.0.0.1/255.0.0.0")
    #
    def initialize(str)
      ip, netmask = split_ip_and_netmask(str)

      if netmask.nil? || netmask =~ PREFIX_RE
        @_prefix = netmask || 32
      elsif self.class.valid_ipv4_netmask?(netmask)
        @prefix  = Prefix.parse_netmask(netmask)
      else
        raise ArgumentError, "Invalid netmask #{netmask.inspect}"
      end

      @address, @octets = ip, addr2ary(ip)
    end

    #
    # Returns the address portion of the IPv4 object
    # as a string.
    #
    #   ip = IPAddress("172.16.100.4/22")
    #
    #   ip.address
    #     #=> "172.16.100.4"
    #
    def address
      lazy_attr(:address) { ary2addr(octets) }
    end

    #
    # Returns the prefix portion of the IPv4 object
    # as a IPAddress::Prefix32 object
    #
    #   ip = IPAddress("172.16.100.4/22")
    #
    #   ip.prefix
    #     #=> 22
    #
    #   ip.prefix.class
    #     #=> IPAddress::Prefix32
    #
    def prefix
      lazy_attr(:prefix, false) { Prefix.new(@_prefix) }
    end

    #
    # Returns the prefix as a string in IP format
    #
    #   ip = IPAddress("172.16.100.4/22")
    #
    #   ip.netmask
    #     #=> "255.255.252.0"
    #
    def netmask
      lazy_attr(:netmask) { prefix.to_ip }
    end

    #
    # Like IPv4#prefix=, this method allow you to
    # change the prefix / netmask of an IP address
    # object.
    #
    #   ip = IPAddress("172.16.100.4")
    #
    #   ip.to_string
    #     #=> 172.16.100.4/16
    #
    #   ip2 = ip.new_netmask("255.255.252.0")
    #
    #   ip2.to_string
    #     #=> 172.16.100.4/22
    #
    def new_netmask(addr)
      new_prefix(Prefix.parse_netmask(addr))
    end

    #
    # Returns the address as an array of decimal values
    #
    #   ip = IPAddress("172.16.100.4")
    #
    #   ip.octets
    #     #=> [172, 16, 100, 4]
    #
    def octets
      lazy_attr(:octets) { int2ary(to_i) }
    end

    alias_method :groups, :octets

    #
    # Returns a string with the address portion of
    # the IPv4 object
    #
    #   ip = IPAddress("172.16.100.4/22")
    #
    #   ip.to_s
    #     #=> "172.16.100.4"
    #
    def to_s
      address
    end

    #
    # Returns the address portion in unsigned
    # 32 bits integer format.
    #
    # This method is identical to the C function
    # inet_pton to create a 32 bits address family
    # structure.
    #
    #   ip = IPAddress("10.0.0.0/8")
    #
    #   ip.to_i
    #     #=> 167772160
    #
    def to_i
      lazy_attr(:int) { ary2int(octets) }
    end

    alias_method :u32, :to_i
    alias_method :to_u32, :to_i

    #
    # Returns the address portion of an IPv4 object
    # in a network byte order format.
    #
    #   ip = IPAddress("172.16.10.1/24")
    #
    #   ip.data
    #     #=> "\254\020\n\001"
    #
    # It is usually used to include an IP address
    # in a data packet to be sent over a socket
    #
    #   a = Socket.open(params) # socket details here
    #   ip = IPAddress("10.1.1.0/24")
    #   binary_data = ["Address: "].pack("a*") + ip.data
    #
    #   # Send binary data
    #   a.puts binary_data
    #
    def data
      lazy_attr(:data) { int2data(to_i) }
    end

    #
    # Returns the octet specified by index
    #
    #   ip = IPAddress("172.16.100.50/24")
    #
    #   ip[0]
    #     #=> 172
    #   ip[1]
    #     #=> 16
    #   ip[2]
    #     #=> 100
    #   ip[3]
    #     #=> 50
    #
    def [](index)
      octets[index]
    end

    alias_method :octet, :[]
    alias_method :group, :[]

    alias_method :network_u32, :network_i

    alias_method :broadcast_u32, :broadcast_i

    #
    # Returns the IP address in in-addr.arpa format
    # for DNS lookups
    #
    #   ip = IPAddress("172.16.100.50/24")
    #
    #   ip.reverse
    #     #=> "50.100.16.172.in-addr.arpa"
    #
    def reverse
      lazy_attr(:reverse) { "#{ary2addr(octets.reverse)}.in-addr.arpa" }
    end

    alias_method :arpa, :reverse

    #
    # Checks if an IPv4 address objects belongs
    # to a private network RFC1918
    #
    # Example:
    #
    #   ip = IPAddress "10.1.1.1/24"
    #   ip.private?
    #     #=> true
    #
    def private?
      lazy_attr(:private_p) { self.class.private_nets.any? { |i| i.include?(self) } }
    end

    #
    # Checks whether the ip address belongs to a
    # RFC 791 CLASS A network, no matter
    # what the subnet mask is.
    #
    # Example:
    #
    #   ip = IPAddress("10.0.0.1/24")
    #
    #   ip.a?
    #     #=> true
    #
    def a?
      lazy_attr(:a_p) { CLASSFUL[8] === bits }
    end

    #
    # Checks whether the ip address belongs to a
    # RFC 791 CLASS B network, no matter
    # what the subnet mask is.
    #
    # Example:
    #
    #   ip = IPAddress("172.16.10.1/24")
    #
    #   ip.b?
    #     #=> true
    #
    def b?
      lazy_attr(:b_p) { CLASSFUL[16] === bits }
    end

    #
    # Checks whether the ip address belongs to a
    # RFC 791 CLASS C network, no matter
    # what the subnet mask is.
    #
    # Example:
    #
    #   ip = IPAddress("192.168.1.1/30")
    #
    #   ip.c?
    #     #=> true
    #
    def c?
      lazy_attr(:c_p) { CLASSFUL[24] === bits }
    end

    #
    # Return the ip address in a format compatible
    # with the IPv6 Mapped IPv4 addresses
    #
    # Example:
    #
    #   ip = IPAddress("172.16.10.1/24")
    #
    #   ip.to_ipv6
    #     #=> "ac10:0a01"
    #
    def to_ipv6
      lazy_attr(:to_ipv6) { '%.4x:%.4x' % int2data(to_i).unpack('n2') }
    end

  end

end
