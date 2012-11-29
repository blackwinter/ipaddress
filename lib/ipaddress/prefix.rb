class IPAddress

  #
  # =NAME
  #
  # IPAddress::Prefix
  #
  # =SYNOPSIS
  #
  # Parent class for Prefix32 and Prefix128
  #
  # =DESCRIPTION
  #
  # IPAddress::Prefix is the parent class for IPAddress::Prefix32
  # and IPAddress::Prefix128, defining some modules in common for
  # both the subclasses.
  #
  # IPAddress::Prefix shouldn't be accesses directly, unless
  # for particular needs.
  #
  class Prefix

    include Comparable

    include Conversions
    extend  Conversions

    include Util::LazyAttr

    #
    # Creates a new prefix object for 32 bits IPv4 addresses /
    # 128 bits IPv6 addresses.
    #
    #   prefix = IPAddress::Prefix32.new(24)
    #     #=> 24
    #
    #   prefix6 = IPAddress::Prefix128.new(64)
    #     #=> 64
    #
    def initialize(num = nil)
      validate_prefix(@prefix = case num
        when self.class then num.prefix
        when nil then max
        else num.to_i
      end)
    end

    attr_reader :prefix

    #
    # Returns a string with the prefix
    #
    def to_s
      prefix.to_s
    end

    def inspect
      "#{self.class}@#{to_s}"
    end

    #
    # Transforms the prefix into a string of bits
    # representing the netmask
    #
    #   prefix32 = IPAddress::Prefix32.new(24)
    #
    #   prefix32.bits
    #     #=> "11111111111111111111111100000000"
    #
    #   prefix128 = IPAddress::Prefix128.new(64)
    #
    #   prefix128.bits
    #     #=> "1111111111111111111111111111111111111111111111111111111111111111"
    #         "0000000000000000000000000000000000000000000000000000000000000000"
    #
    def bits
      lazy_attr(:bits) { '1' * prefix << '0' * host_prefix }
    end

    #
    # Unsigned 32/128 bits decimal number representing
    # the prefix
    #
    #   prefix = IPAddress::Prefix32.new(24)
    #
    #   prefix.to_u32
    #     #=> 4294967040
    #
    #   prefix6 = IPAddress::Prefix128.new(64)
    #
    #   prefix6.to_u128
    #     #=> 340282366920938463444927863358058659840
    #
    def to_i
      lazy_attr(:int) { bits.to_i(2) }
    end

    #
    # Compare the prefix
    #
    def <=>(other)
      prefix <=> other.prefix
    end

    def hash
      prefix.hash
    end

    alias_method :eql?, :==

    #
    # Sums two prefixes or a prefix to a
    # number, returns a Fixnum
    #
    def +(other)
      prefix + (other.is_a?(self.class) ? other.prefix : other)
    end

    #
    # Returns the difference between two
    # prefixes, or a prefix and a number,
    # as a Fixnum
    #
    def -(other)
      (prefix - (other.is_a?(self.class) ? other.prefix : other)).abs
    end

    #
    # Returns the length of the host portion
    # of a netmask.
    #
    #   prefix32 = Prefix32.new(24)
    #
    #   prefix32.host_prefix
    #     #=> 8
    #
    #   prefix128 = Prefix128.new(96)
    #
    #   prefix128.host_prefix
    #     #=> 32
    #
    def host_prefix
      lazy_attr(:host_prefix) { max - prefix }
    end

    def max
      lazy_attr(:max) { self.class::MAX }
    end

    def max?
      lazy_attr(:max_p) { prefix == max }
    end

    def prev
      lazy_attr(:prev) { prefix - 1 }
    end

    def next
      lazy_attr(:next) { prefix + 1 unless max? }
    end

    def superprefix(num, relax = false)
      validate_prefix([0, num].max, nil, prev, relax) or return
    end

    def subprefix(num, relax = false)
      validate_prefix(num, prefix, relax) or return
      [2 ** (max - num), 2 ** (num - prefix)]
    end

    def validate_prefix(num, first = nil, last = nil, relax = false)
      return num if (range = (first || 0)..(last || max)).include?(num)
      raise ArgumentError, "Prefix must be in range #{range}, got: #{num}" unless relax
    end

  end

  class Prefix32 < Prefix

    MAX = 32

    class << self

      #
      # Creates a new prefix by parsing a netmask in
      # dotted decimal form
      #
      #   prefix = IPAddress::Prefix32.parse_netmask("255.255.255.0")
      #     #=> 24
      #
      def parse_netmask(netmask)
        octets = addr2ary(netmask)
        new(data2bits(octets.pack("C#{octets.size}")).count('1'))
      end

    end

    alias_method :to_u32, :to_i

    #
    # Gives the prefix in IPv4 dotted decimal format,
    # i.e. the canonical netmask we're all used to
    #
    #   prefix = IPAddress::Prefix32.new(24)
    #
    #   prefix.to_ip
    #     #=> "255.255.255.0"
    #
    def to_ip
      lazy_attr(:ip) { bits2addr(bits) }
    end

    #
    # An array of octets of the IPv4 dotted decimal
    # format
    #
    #   prefix = IPAddress::Prefix32.new(24)
    #
    #   prefix.octets
    #     #=> [255, 255, 255, 0]
    #
    def octets
      lazy_attr(:octets) { addr2ary(to_ip) }
    end

    #
    # Shortcut for the octecs in the dotted decimal
    # representation
    #
    #   prefix = IPAddress::Prefix32.new(24)
    #
    #   prefix[2]
    #     #=> 255
    #
    def [](index)
      octets[index]
    end

    alias_method :octet, :[]

    #
    # The hostmask is the contrary of the subnet mask,
    # as it shows the bits that can change within the
    # hosts
    #
    #   prefix = IPAddress::Prefix32.new(24)
    #
    #   prefix.hostmask
    #     #=> "0.0.0.255"
    #
    def hostmask
      lazy_attr(:hostmask) { int2addr(~to_i) }
    end

  end

  class Prefix128 < Prefix

    MAX = 128

    alias_method :to_u128, :to_i

  end

  MAX_PREFIX = Prefix128::MAX

end
