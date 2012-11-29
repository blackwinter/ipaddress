class IPAddress

  #
  # =Name
  #
  # IPAddress::IPv6 - IP version 6 address manipulation library
  #
  # =Synopsis
  #
  #    require 'ipaddress'
  #
  # =Description
  #
  # Class IPAddress::IPv6 is used to handle IPv6 type addresses.
  #
  # == IPv6 addresses
  #
  # IPv6 addresses are 128 bits long, in contrast with IPv4 addresses
  # which are only 32 bits long. An IPv6 address is generally written as
  # eight groups of four hexadecimal digits, each group representing 16
  # bits or two octect. For example, the following is a valid IPv6
  # address:
  #
  #   2001:0db8:0000:0000:0008:0800:200c:417a
  #
  # Letters in an IPv6 address are usually written downcase, as per
  # RFC. You can create a new IPv6 object using uppercase letters, but
  # they will be converted.
  #
  # === Compression
  #
  # Since IPv6 addresses are very long to write, there are some
  # semplifications and compressions that you can use to shorten them.
  #
  # * Leading zeroes: all the leading zeroes within a group can be
  #   omitted: "0008" would become "8"
  #
  # * A string of consecutive zeroes can be replaced by the string
  #   "::". This can be only applied once.
  #
  # Using compression, the IPv6 address written above can be shorten into
  # the following, equivalent, address
  #
  #   2001:db8::8:800:200c:417a
  #
  # This short version is often used in human representation.
  #
  # === Network Mask
  #
  # As we used to do with IPv4 addresses, an IPv6 address can be written
  # using the prefix notation to specify the subnet mask:
  #
  #   2001:db8::8:800:200c:417a/64
  #
  # The /64 part means that the first 64 bits of the address are
  # representing the network portion, and the last 64 bits are the host
  # portion.
  #
  #
  class IPv6 < self

    part1 = %r{ [\dA-Fa-f]{1,4} }x

    part2 = %r{ #{part1} (?: : #{part1} )* }xo

    part3 = %r{ :: (?: #{part2} )? }xo

    part4 = %r{ \A (?: #{part2} #{part3} | #{part2} | #{part3} ) }xo

    #
    # Regular expression to match an IPv6 address
    #
    RE = %r{ #{part4} (?: : #{IPv4::INTERNAL_RE} )? \z }xo

    #
    # Format string to pretty print IPv6 addresses
    #
    IN6FORMAT = Array.new(8, '%.4x').join(':')

    Prefix = Prefix128

    MAX_PREFIX = Prefix::MAX

    class << self

      alias_method :valid_ip?, :valid_ipv6?

      #
      # Creates a new IPv6 object from an
      # unsigned 128 bits integer.
      #
      #   ip6 = IPAddress::IPv6.parse_u128(42540766411282592856906245548098208122)
      #
      #   ip6.to_string
      #     #=> "2001:db8::8:800:200c:417a/128"
      #
      # The +prefix+ parameter is optional:
      #
      #   ip6 = IPAddress::IPv6.parse_u128(42540766411282592856906245548098208122, 64)
      #
      #   ip6.to_string
      #     #=> "2001:db8::8:800:200c:417a/64"
      #
      def parse_i(i, prefix = MAX_PREFIX)
        groups = Array.new(8) { |j| i >> (112 - 16 * j) & 0xffff }
        instantiate { @groups, @netmask = groups, prefix }
      end

      alias_method :parse_u128, :parse_i

      #
      # Creates a new IPv6 object from binary data,
      # like the one you get from a network stream.
      #
      # For example, on a network stream the IP
      #
      #  "2001:db8::8:800:200c:417a"
      #
      # is represented with the binary data
      #
      #   " \001\r\270\000\000\000\000\000\b\b\000 \fAz"
      #
      # With that data you can create a new IPv6 object:
      #
      #   ip6 = IPAddress::IPv6.parse_data(" \001\r\270\000\000\000\000\000\b\b\000 \fAz", 64)
      #
      #   ip6.to_s
      #     #=> "2001:db8::8:800:200c:417a/64"
      #
      def parse_data(str, prefix = MAX_PREFIX)
        instantiate { @groups, @netmask = str.unpack('n8'), prefix }
      end

      #
      # Creates a new IPv6 object from a number expressed in
      # hexdecimal format:
      #
      #   ip6 = IPAddress::IPv6.parse_hex("20010db80000000000080800200c417a")
      #
      #   ip6.to_string
      #     #=> "2001:db8::8:800:200c:417a/128"
      #
      # The +prefix+ parameter is optional:
      #
      #   ip6 = IPAddress::IPv6.parse_hex("20010db80000000000080800200c417a", 64)
      #
      #   ip6.to_string
      #     #=> "2001:db8::8:800:200c:417a/64"
      #
      def parse_hex(hex, prefix = MAX_PREFIX)
        parse_i(hex.hex, prefix)
      end

      #
      # Expands an IPv6 address in the canocical form
      #
      #   IPAddress::IPv6.expand("2001:0DB8:0:CD30::")
      #     #=> "2001:0DB8:0000:CD30:0000:0000:0000:0000"
      #
      def expand(str)
        new(str).address
      end

      #
      # Compress an IPv6 address in its compressed form
      #
      #   IPAddress::IPv6.compress("2001:0DB8:0000:CD30:0000:0000:0000:0000")
      #     #=> "2001:db8:0:cd30::"
      #
      def compress(str)
        new(str).compressed
      end

      #
      # Extract 16 bits groups from a string
      #
      def groups(str)
        l, r = str.split('::', 2).map! { |i| i.split(':').map! { |j| j.hex } }
        l.concat(Array.new(8 - l.size - (r ||= []).size, 0)).concat(r)
      end

    end

    #
    # Creates a new IPv6 address object.
    #
    # An IPv6 address can be expressed in any of the following forms:
    #
    # * "2001:0db8:0000:0000:0008:0800:200C:417A": IPv6 address with no compression
    # * "2001:db8:0:0:8:800:200C:417A": IPv6 address with leading zeros compression
    # * "2001:db8::8:800:200C:417A": IPv6 address with full compression
    #
    # In all these 3 cases, a new IPv6 address object will be created, using the default
    # subnet mask /128
    #
    # You can also specify the subnet mask as with IPv4 addresses:
    #
    #   ip6 = IPAddress("2001:db8::8:800:200c:417a/64")
    #
    def initialize(str)
      unless str =~ /:.+\./
        @ip, @netmask = split_ip_and_netmask(str)
      else
        raise ArgumentError, "Use #{self.class}::Mapped for IPv4 mapped addresses"
      end
    end

    def version
      6
    end

    #
    # Returns the IPv6 address in uncompressed form:
    #
    #   ip6 = IPAddress("2001:db8::8:800:200c:417a/64")
    #
    #   ip6.address
    #     #=> "2001:0db8:0000:0000:0008:0800:200c:417a"
    #
    def address
      lazy_attr(:address) { IN6FORMAT % groups }
    end

    #
    # Compressed form of the IPv6 address
    #
    #   ip6 = IPAddress("2001:db8::8:800:200c:417a/64")
    #
    #   ip6.compressed
    #     #=> "2001:db8::8:800:200c:417a"
    #
    def compressed
      lazy_attr(:compressed) {
        r1, r2, q = /\b0(?::0)+\b/, /:{3,}/, '::'

        a, b = [s = groups.map { |i| i.to_s(16) }.join(':'), s.reverse].map! { |t|
          t.sub!(r1, q) && t.sub!(r2, q) || t
        }

        a.length > b.length ? b.reverse! : a
      }
    end

    #
    # Returns an instance of the prefix object
    #
    #   ip6 = IPAddress("2001:db8::8:800:200c:417a/64")
    #
    #   ip6.prefix
    #     #=> 64
    #
    def prefix
      lazy_attr(:prefix, false) { Prefix.new(@netmask) }
    end

    #
    # Returns an array with the 16 bits groups in decimal
    # format:
    #
    #   ip6 = IPAddress("2001:db8::8:800:200c:417a/64")
    #
    #   ip6.groups
    #     #=> [8193, 3512, 0, 0, 8, 2048, 8204, 16762]
    #
    def groups
      lazy_attr(:groups) { self.class.groups(@ip) }
    end

    #
    # Returns an array of the 16 bits groups in hexdecimal
    # format:
    #
    #   ip6 = IPAddress("2001:db8::8:800:200c:417a/64")
    #
    #   ip6.hexs
    #     #=> ["2001", "0db8", "0000", "0000", "0008", "0800", "200c", "417a"]
    #
    # Not to be confused with the similar IPv6#to_hex method.
    #
    def hexs
      lazy_attr(:hexs) { address.split(':') }
    end

    #
    # Returns a Base16 number representing the IPv6
    # address
    #
    #   ip6 = IPAddress("2001:db8::8:800:200c:417a/64")
    #
    #   ip6.to_hex
    #     #=> "20010db80000000000080800200c417a"
    #
    def to_hex
      lazy_attr(:to_hex) { hexs.join('') }
    end

    #
    # Returns the IPv6 address in a human readable form,
    # using the compressed address.
    #
    #   ip6 = IPAddress("2001:db8::8:800:200c:417a/64")
    #
    #   ip6.to_s
    #     #=> "2001:db8::8:800:200c:417a"
    #
    def to_s
      compressed
    end

    #
    # Unlike its counterpart IPv6#to_string method, IPv6#to_string_uncompressed
    # returns the whole IPv6 address and prefix in an uncompressed form
    #
    #   ip6 = IPAddress("2001:db8::8:800:200c:417a/64")
    #
    #   ip6.to_string_uncompressed
    #     #=> "2001:0db8:0000:0000:0008:0800:200c:417a/64"
    #
    def to_string_uncompressed
      "#{address}/#{prefix}"
    end

    #
    # Returns a decimal format (unsigned 128 bit) of the
    # IPv6 address
    #
    #   ip6 = IPAddress("2001:db8::8:800:200c:417a/64")
    #
    #   ip6.to_i
    #     #=> 42540766411282592856906245548098208122
    #
    def to_i
      lazy_attr(:int) { to_hex.hex }
    end

    alias_method :u128, :to_i
    alias_method :to_u128, :to_i

    # Returns the address portion of an IPv6 object
    # in a network byte order format.
    #
    #   ip6 = IPAddress("2001:db8::8:800:200c:417a/64")
    #
    #   ip6.data
    #     #=> " \001\r\270\000\000\000\000\000\b\b\000 \fAz"
    #
    # It is usually used to include an IP address
    # in a data packet to be sent over a socket
    #
    #   a = Socket.open(params) # socket details here
    #   ip6 = IPAddress("2001:db8::8:800:200c:417a/64")
    #   binary_data = ["Address: "].pack("a*") + ip.data
    #
    #   # Send binary data
    #   a.puts binary_data
    #
    def data
      lazy_attr(:data) { groups.pack('n8') }
    end

    #
    # Returns the 16-bits value specified by index
    #
    #   ip = IPAddress("2001:db8::8:800:200c:417a/64")
    #
    #   ip[0]
    #     #=> 8193
    #   ip[1]
    #     #=> 3512
    #   ip[2]
    #     #=> 0
    #   ip[3]
    #     #=> 0
    #
    def [](index)
      groups[index]
    end

    alias_method :group, :[]

    alias_method :network_u128, :network_i

    alias_method :broadcast_u128, :broadcast_i

    #
    # Returns the IPv6 address in a DNS reverse lookup
    # string, as per RFC3172 and RFC2874.
    #
    #   ip6 = IPAddress("3ffe:505:2::f")
    #
    #   ip6.reverse
    #     #=> "f.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.2.0.0.0.5.0.5.0.e.f.f.3.ip6.arpa"
    #
    def reverse
      lazy_attr(:reverse) { "#{to_hex.gsub(/(?=.)/, '.').reverse}ip6.arpa" }
    end

    alias_method :arpa, :reverse

    #
    # Literal version of the IPv6 address
    #
    #   ip6 = IPAddress("2001:db8::8:800:200c:417a/64")
    #
    #   ip6.literal
    #     #=> "2001-0db8-0000-0000-0008-0800-200c-417a.ipv6-literal.net"
    #
    def literal
      lazy_attr(:literal) { "#{address.tr(':', '-')}.ipv6-literal.net" }
    end

    #
    # Returns true if the address is an unspecified address
    #
    # See IPAddress::IPv6::Unspecified for more information
    #
    def unspecified?
      lazy_attr(:unspecified_p) { prefix.max? && compressed == '::' }
    end

    #
    # Returns true if the address is a loopback address
    #
    # See IPAddress::IPv6::Loopback for more information
    #
    def loopback?
      lazy_attr(:loopback_p) { prefix.max? && compressed == '::1' }
    end

    #
    # Returns true if the address is a mapped address
    #
    # See IPAddress::IPv6::Mapped for more information
    #
    def mapped?
      lazy_attr(:mapped_p) { to_i >> 32 == 0xffff }
    end

    #
    # The address with all zero bits is called the +unspecified+ address
    # (corresponding to 0.0.0.0 in IPv4). It should be something like this:
    #
    #   0000:0000:0000:0000:0000:0000:0000:0000
    #
    # but, with the use of compression, it is usually written as just two
    # colons:
    #
    #   ::
    #
    # or, specifying the netmask:
    #
    #   ::/128
    #
    # With IPAddress, create a new unspecified IPv6 address using its own
    # subclass:
    #
    #   ip = IPAddress::IPv6::Unspecified.new
    #
    #   ip.to_s
    #     #=> => "::/128"
    #
    # You can easily check if an IPv6 object is an unspecified address by
    # using the IPv6#unspecified? method
    #
    #   ip.unspecified?
    #     #=> true
    #
    # An unspecified IPv6 address can also be created with the wrapper
    # method, like we've seen before
    #
    #   ip = IPAddress("::")
    #
    #   ip.unspecified?
    #     #=> true
    #
    # This address must never be assigned to an interface and is to be used
    # only in software before the application has learned its host's source
    # address appropriate for a pending connection. Routers must not forward
    # packets with the unspecified address.
    #
    class Unspecified < self

      #
      # Creates a new IPv6 unspecified address
      #
      #   ip = IPAddress::IPv6::Unspecified.new
      #
      #   ip.to_string
      #      #=> => "::/128"
      #
      def initialize
        @groups = Array.new(8, 0)
      end

    end

    #
    #   The loopback  address is a unicast localhost address. If an
    # application in a host sends packets to this address, the IPv6 stack
    # will loop these packets back on the same virtual interface.
    #
    # Loopback addresses are expressed in the following form:
    #
    #   ::1
    #
    # or, with their appropriate prefix,
    #
    #   ::1/128
    #
    # As for the unspecified addresses, IPv6 loopbacks can be created with
    # IPAddress calling their own class:
    #
    #   ip = IPAddress::IPv6::Loopback.new
    #
    #   ip.to_string
    #     #=> "::1/128"
    #
    # or by using the wrapper:
    #
    #   ip = IPAddress("::1")
    #
    #   ip.to_string
    #     #=> "::1/128"
    #
    # Checking if an address is loopback is easy with the IPv6#loopback?
    # method:
    #
    #   ip.loopback?
    #     #=> true
    #
    # The IPv6 loopback address corresponds to 127.0.0.1 in IPv4.
    #
    class Loopback < self

      #
      # Creates a new IPv6 unspecified address
      #
      #   ip = IPAddress::IPv6::Loopback.new
      #
      #   ip.to_string
      #     #=> "::1/128"
      #
      def initialize
        @groups = Array.new(7, 0) << 1
      end

    end

    #
    # It is usually identified as a IPv4 mapped IPv6 address, a particular
    # IPv6 address which aids the transition from IPv4 to IPv6. The
    # structure of the address is
    #
    #   ::ffff:w.y.x.z
    #
    # where w.x.y.z is a normal IPv4 address. For example, the following is
    # a mapped IPv6 address:
    #
    #   ::ffff:192.168.100.1
    #
    # IPAddress is very powerful in handling mapped IPv6 addresses, as the
    # IPv4 portion is stored internally as a normal IPv4 object. Let's have
    # a look at some examples. To create a new mapped address, just use the
    # class builder itself
    #
    #   ip6 = IPAddress::IPv6::Mapped.new("::ffff:172.16.10.1/128")
    #
    # or just use the wrapper method
    #
    #   ip6 = IPAddress("::ffff:172.16.10.1/128")
    #
    # Let's check it's really a mapped address:
    #
    #   ip6.mapped?
    #     #=> true
    #
    #   ip6.to_string
    #     #=> "::FFFF:172.16.10.1/128"
    #
    # Now with the +ipv4+ attribute, we can easily access the IPv4 portion
    # of the mapped IPv6 address:
    #
    #   ip6.ipv4.address
    #     #=> "172.16.10.1"
    #
    # Internally, the IPv4 address is stored as two 16 bits
    # groups. Therefore all the usual methods for an IPv6 address are
    # working perfectly fine:
    #
    #   ip6.to_hex
    #     #=> "00000000000000000000ffffac100a01"
    #
    #   ip6.address
    #     #=> "0000:0000:0000:0000:0000:ffff:ac10:0a01"
    #
    # A mapped IPv6 can also be created just by specify the address in the
    # following format:
    #
    #   ip6 = IPAddress("::172.16.10.1")
    #
    # That is, two colons and the IPv4 address. However, as by RFC, the ffff
    # group will be automatically added at the beginning
    #
    #   ip6.to_string
    #     => "::ffff:172.16.10.1/128"
    #
    # making it a mapped IPv6 compatible address.
    #
    class Mapped < self

      #
      # Creates a new IPv6 IPv4-mapped address
      #
      #   ip6 = IPAddress::IPv6::Mapped.new("::ffff:172.16.10.1/128")
      #
      #   ipv6.ipv4.class
      #     #=> IPAddress::IPv4
      #
      # An IPv6 IPv4-mapped address can also be created using the
      # IPv6 only format of the address:
      #
      #   ip6 = IPAddress::IPv6::Mapped.new("::0d01:4403")
      #
      #   ip6.to_string
      #     #=> "::ffff:13.1.68.3"
      #
      def initialize(str)
        ip, netmask = split_ip_and_netmask(str, false)

        @ipv4 = if ip =~ /\./
          IPv4.extract(ip)
        else
          groups = self.class.groups(ip)
          IPv4.parse_i((groups[-2] << 16) + groups[-1])
        end

        super("::ffff:#{ipv4.to_ipv6}/#{netmask}")
      end

      # Access the internal IPv4 address
      attr_reader :ipv4

      #
      # Similar to IPv6#to_s, but prints out the IPv4 address
      # in dotted decimal format
      #
      #   ip6 = IPAddress("::ffff:172.16.10.1/128")
      #
      #   ip6.to_s
      #     #=> "::ffff:172.16.10.1"
      #
      def to_s
        "::ffff:#{ipv4}"
      end

      #
      # Similar to IPv6#to_string, but prints out the IPv4 address
      # in dotted decimal format
      #
      #
      #   ip6 = IPAddress "::ffff:172.16.10.1/128"
      #
      #   ip6.to_string
      #     #=> "::ffff:172.16.10.1/128"
      #
      def to_string
        super
      end

      #
      # Checks if the IPv6 address is IPv4 mapped
      #
      #   ip6 = IPAddress "::ffff:172.16.10.1/128"
      #
      #   ip6.mapped?
      #     #=> true
      #
      def mapped?
        true
      end

    end

  end

end
