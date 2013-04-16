#
# = IPAddress
#
# A ruby library to manipulate IPv4 and IPv6 addresses
#
#
# Package::     IPAddress
# Author::      Marco Ceresa <ceresa@ieee.org>
# License::     Ruby License
#
#--
#
#++

require 'ipaddress/conversions'
require 'nuggets/lazy_attr'

class IPAddress

  include Enumerable
  include Comparable

  include Conversions
  extend  Conversions

  include Nuggets::LazyAttr

  VERSION = '0.8.0.2'
  NAME    = 'IPAddress'
  GEM     = 'ipaddress'
  AUTHORS = ['Marco Ceresa <ceresa@ieee.org>']

  class << self

    #
    # Parse the argument string to create a new
    # IPv4, IPv6 or Mapped IP object
    #
    #   ip  = IPAddress.parse "172.16.10.1/24"
    #   ip6 = IPAddress.parse "2001:db8::8:800:200c:417a/64"
    #   ip_mapped = IPAddress.parse "::ffff:172.16.10.1/128"
    #
    # All the object created will be instances of the
    # correct class:
    #
    #  ip.class
    #    #=> IPAddress::IPv4
    #  ip6.class
    #    #=> IPAddress::IPv6
    #  ip_mapped.class
    #    #=> IPAddress::IPv6::Mapped
    #
    def parse(str)
      case str
        when /:.+\./ then IPv6::Mapped.new(str)
        when /\./    then IPv4.new(str)
        when /:/     then IPv6.new(str)
        else raise ArgumentError, "Unknown IP Address #{str.inspect}"
      end
    end

    def parse_i(version, i, prefix = nil)
      case version
        when 4
          IPv4.parse_i(i, prefix || IPv4::MAX_PREFIX)
        when 6
          IPv6.parse_i(i, prefix || IPv6::MAX_PREFIX).instance_eval { mapped || self }
        else
          raise ArgumentError, "IP protocol version not supported: #{version.inspect}"
      end
    end

    #
    # Checks if the given string is a valid IP address,
    # either IPv4 or IPv6
    #
    # Example:
    #
    #   IPAddress::valid? "2002::1"
    #     #=> true
    #
    #   IPAddress::valid? "10.0.0.256"
    #     #=> false
    #
    def valid?(addr)
      valid_ipv4?(addr) || valid_ipv6?(addr)
    end

    #
    # Checks if the given string is a valid IPv4 address
    #
    # Example:
    #
    #   IPAddress::valid_ipv4? "2002::1"
    #     #=> false
    #
    #   IPAddress::valid_ipv4? "172.16.10.1"
    #     #=> true
    #
    def valid_ipv4?(addr)
      IPv4::RE === addr
    end

    #
    # Checks if the argument is a valid IPv4 netmask
    # expressed in dotted decimal format.
    #
    #   IPAddress.valid_ipv4_netmask? "255.255.0.0"
    #     #=> true
    #
    def valid_ipv4_netmask?(addr)
      valid_ipv4?(addr) && addr2bits(addr) !~ /01/
    end

    #
    # Checks if the given string is a valid IPv6 address
    #
    # Example:
    #
    #   IPAddress::valid_ipv6? "2002::1"
    #     #=> true
    #
    #   IPAddress::valid_ipv6? "2002::1::2"
    #     #=> false
    #
    def valid_ipv6?(addr)
      IPv6::RE === addr
    end

    #
    # Summarization (or aggregation) is the process when two or more
    # networks are taken together to check if a supernet, including all
    # and only these networks, exists. If it exists then this supernet
    # is called the summarized (or aggregated) network.
    #
    # It is very important to understand that summarization can only
    # occur if there are no holes in the aggregated network, or, in other
    # words, if the given networks fill completely the address space
    # of the supernet. So the two rules are:
    #
    # 1) The aggregate network must contain +all+ the IP addresses of the
    #    original networks;
    # 2) The aggregate network must contain +only+ the IP addresses of the
    #    original networks;
    #
    # A few examples will help clarify the above. Let's consider for
    # instance the following two networks:
    #
    #   ip1 = IPAddress("172.16.10.0/24")
    #   ip2 = IPAddress("172.16.11.0/24")
    #
    # These two networks can be expressed using only one IP address
    # network if we change the prefix. Let Ruby do the work:
    #
    #   IPAddress::IPv4.summarize(ip1,ip2).map { |i| i.to_string }
    #     #=> ["172.16.10.0/23"]
    #
    # We note how the network "172.16.10.0/23" includes all the addresses
    # specified in the above networks, and (more important) includes
    # ONLY those addresses.
    #
    # If we summarized +ip1+ and +ip2+ with the following network:
    #
    #   "172.16.0.0/16"
    #
    # we would have satisfied rule #1 above, but not rule #2. So "172.16.0.0/16"
    # is not an aggregate network for +ip1+ and +ip2+.
    #
    # If it's not possible to compute a single aggregated network for all the
    # original networks, the method returns an array with all the aggregate
    # networks found. For example, the following four networks can be
    # aggregated in a single /22:
    #
    #   ip1 = IPAddress("10.0.0.1/24")
    #   ip2 = IPAddress("10.0.1.1/24")
    #   ip3 = IPAddress("10.0.2.1/24")
    #   ip4 = IPAddress("10.0.3.1/24")
    #
    #   IPAddress::IPv4.summarize(ip1,ip2,ip3,ip4).map { |i| i.to_string }
    #     #=> ["10.0.0.0/22"]
    #
    # But the following networks can't be summarized in a single network:
    #
    #   ip1 = IPAddress("10.0.1.1/24")
    #   ip2 = IPAddress("10.0.2.1/24")
    #   ip3 = IPAddress("10.0.3.1/24")
    #   ip4 = IPAddress("10.0.4.1/24")
    #
    #   IPAddress::IPv4.summarize(ip1,ip2,ip3,ip4).map { |i| i.to_string }
    #     #=> ["10.0.1.0/24","10.0.2.0/23","10.0.4.0/24"]
    #
    def summarize(*nets)
      nets.sort!.map! { |i| i.network }
      return nets unless nets.size > 1

      loop {
        i, f = -1, false

        while i < nets.size - 2
          i1, i2 = nets[i += 1, 2]

          if s = i1.proper_supernet(i2)
            nets[i, 2], f = s, true
          end
        end

        return nets unless f
      }
    end

    def subtract(a, *b)
      subtract!(a.is_a?(Array) ? a.dup : [a], *b)
    end

    def subtract!(a, *b)
      raise TypeError, "Array expected, got #{a.class}" unless a.is_a?(Array)

      a.uniq!; b.flatten!; b.uniq!
      c, d = [], b.map { |i| i.boundaries }

      loop {
        a.delete_if { |i|
          b.any? { |j| j.include?(i) } || if i.overlap_i?(*d)
            (n = i.prefix.next) ? c.concat(i.subnet(n)) : c << i
          end
        }

        c.empty? ? break : a.concat(c); c.clear
      }

      a.replace(summarize(*a)).sort!
    end

    private

    def instantiate(&block)
      instance = allocate
      instance.instance_eval(&block)
      instance
    end

    #
    # Deprecate method
    #
    def deprecate(message = nil) # :nodoc:
      warn("DEPRECATION WARNING: #{message || 'You are using deprecated behavior which will be removed from the next major or minor release.'}")
    end

  end

  #
  # True if the object is an IPv4 address
  #
  #   ip = IPAddress("192.168.10.100/24")
  #
  #   ip.ipv4?
  #     #-> true
  #
  def ipv4?
    is_a?(IPv4)
  end

  #
  # True if the object is an IPv6 address
  #
  #   ip = IPAddress("192.168.10.100/24")
  #
  #   ip.ipv6?
  #     #-> false
  #
  def ipv6?
    is_a?(IPv6)
  end

  #
  # Returns a string with the IP address in canonical
  # form.
  #
  #   ip = IPAddress("172.16.100.4/22")
  #
  #   ip.to_string
  #     #=> "172.16.100.4/22"
  #
  #   ip6 = IPAddress("2001:0db8:0000:0000:0008:0800:200c:417a/64")
  #
  #   ip6.to_string
  #     #=> "2001:db8::8:800:200c:417a/64"
  #
  def to_string
    "#{to_s}/#{prefix}"
  end

  def inspect
    "#{self.class}@#{to_string}"
  end

  #
  # Returns the address portion of an IP in binary format,
  # as a string containing a sequence of 0 and 1
  #
  #   ip = IPAddress("127.0.0.1")
  #
  #   ip.bits
  #     #=> "01111111000000000000000000000001"
  #
  #   ip6 = IPAddress("2001:db8::8:800:200c:417a")
  #
  #   ip6.bits
  #     #=> "0010000000000001000011011011100000 [...] "
  #
  def bits
    lazy_attr(:bits) { data2bits(data) }
  end

  #
  # Checks if the IP address is actually a network
  #
  #   ip = IPAddress("172.16.10.64/24")
  #
  #   ip.network?
  #     #=> false
  #
  #   ip = IPAddress("172.16.10.64/26")
  #
  #   ip.network?
  #     #=> true
  #
  #   ip6 = IPAddress("2001:db8::8:800:200c:417a/64")
  #
  #   ip6.network?
  #     #=> false
  #
  #   ip6 = IPAddress("2001:db8:8:800::/64")
  #
  #   ip6.network?
  #     #=> true
  #
  def network?
    lazy_attr(:network_p) { i = prefix.to_i; to_i | i == i }
  end

  #
  # Returns a new IPv4/IPv6 object with the network number
  # for the given IP.
  #
  #   ip = IPAddress("172.16.10.64/24")
  #
  #   ip.network.to_s
  #     #=> "172.16.10.0"
  #
  #   ip6 = IPAddress("2001:db8:1:1:1:1:1:1/32")
  #
  #   ip6.network.to_string
  #     #=> "2001:db8::/32"
  #
  def network
    lazy_attr(:network, false) { network? ? self : at(0) }
  end

  #
  # Returns the network number in Unsigned 32bits/128bits format
  #
  #   ip = IPAddress("10.0.0.1/29")
  #
  #   ip.network_u32
  #     #=> 167772160
  #
  #   ip6 = IPAddress("2001:db8::8:800:200c:417a/64")
  #
  #   ip6.network_u128
  #     #=> 42540766411282592856903984951653826560
  #
  def network_i
    lazy_attr(:network_i) { to_i & prefix.to_i }
  end

  #
  # Returns the broadcast address for the given IP.
  #
  #   ip = IPAddress("172.16.10.64/24")
  #
  #   ip.broadcast.to_s
  #     #=> "172.16.10.255"
  #
  def broadcast
    lazy_attr(:broadcast, false) { at(-1) }
  end

  #
  # Returns the broadcast address in Unsigned 32bits/128bits format
  #
  #   ip = IPaddress("10.0.0.1/29")
  #
  #   ip.broadcast_u32
  #     #=> 167772167
  #
  #   ip6 = IPAddress("2001:db8::8:800:200c:417a/64")
  #
  #   ip6.broadcast_u128
  #     #=> 42540766411282592875350729025363378175
  #
  # Please note that there is no Broadcast concept in IPv6
  # addresses as in IPv4 addresses, and this method is just
  # a helper to other functions.
  #
  def broadcast_i
    lazy_attr(:broadcast_i) { network_i + size - 1 }
  end

  #
  # Returns the number of IP addresses included
  # in the network. It also counts the network
  # address and the broadcast address.
  #
  #   ip = IPAddress("10.0.0.1/29")
  #
  #   ip.size
  #     #=> 8
  #
  #   ip6 = IPAddress("2001:db8::8:800:200c:417a/64")
  #
  #   ip6.size
  #     #=> 18446744073709551616
  #
  def size
    lazy_attr(:size) { 2 ** prefix.host_prefix }
  end

  #
  # Set a new prefix number for the object
  #
  # This is useful if you want to change the prefix
  # to an object created with IPv4.parse_u32/IPv6.parse_u128
  # or if the object was created using the classful mask/
  # the default prefix of 128 bits.
  #
  #   ip = IPAddress("172.16.100.4")
  #
  #   ip.to_string
  #     #=> 172.16.100.4/16
  #
  #   ip2 = ip.new_prefix(22)
  #
  #   ip2.to_string
  #     #=> 172.16.100.4/22
  #
  #   ip6 = IPAddress("2001:db8::8:800:200c:417a")
  #
  #   ip6.to_string
  #     #=> "2001:db8::8:800:200c:417a/128"
  #
  #   ip2 = ip6.new_prefix(64)
  #
  #   ip2.to_string
  #     #=> "2001:db8::8:800:200c:417a/64"
  #
  def new_prefix(prefix)
    self.class.parse_i(to_i, prefix)
  end

  #
  # Checks whether a subnet includes the given IP address.
  #
  # Accepts an IPAddress::IPv4 object.
  #
  #   ip = IPAddress("192.168.10.100/24")
  #   addr = IPAddress("192.168.10.102/24")
  #
  #   ip.include?(addr)
  #     #=> true
  #
  #   ip.include?(IPAddress("172.16.0.48/16"))
  #     #=> false
  #
  #   ip6 = IPAddress("2001:db8::8:800:200c:417a/64")
  #   addr = IPAddress("2001:db8::8:800:200c:1/128")
  #
  #   ip6.include?(addr)
  #     #=> true
  #
  #   ip6.include?(IPAddress("2001:db8:1::8:800:200c:417a/76"))
  #     #=> false
  #
  def include?(other)
    prefix <= other.prefix && network_i == other.to_i & prefix.to_i
  end

  #
  # Checks whether a subnet includes all the
  # given IP objects.
  #
  #   ip = IPAddress("192.168.10.100/24")
  #
  #   addr1 = IPAddress("192.168.10.102/24")
  #   addr2 = IPAddress("192.168.10.103/24")
  #
  #   ip.include_all?(addr1, addr2)
  #     #=> true
  #
  def include_all?(*other)
    other.all? { |i| include?(i) }
  end

  def include_exactly?(*other)
    s = size
    other.each { |i| s -= i.size }
    s == 0 && include_all?(*other)
  end

  def overlap?(*other)
    overlap_i?(*other.map! { |i| i.boundaries })
  end

  def overlap_i?(*other)
    f, l = boundaries
    !other.all? { |i, j| l < i || f > j }
  end

  #
  # Splits a network into different subnets
  #
  # If the IP Address is a network, it can be divided into
  # multiple networks. If +self+ is not a network, this
  # method will calculate the network from the IP and then
  # subnet it.
  #
  # If +subnets+ is an power of two number, the resulting
  # networks will be divided evenly from the supernet.
  #
  #   network = IPAddress("172.16.10.0/24")
  #
  #   (network / 4).map { |i| i.to_string }
  #     #=> ["172.16.10.0/26",
  #          "172.16.10.64/26",
  #          "172.16.10.128/26",
  #          "172.16.10.192/26"]
  #
  # If +num+ is any other number, the supernet will be
  # divided into some networks with a even number of hosts and
  # other networks with the remaining addresses.
  #
  #   network = IPAddress("172.16.10.0/24")
  #
  #   (network / 3).map { |i| i.to_string }
  #     #=> ["172.16.10.0/26",
  #          "172.16.10.64/26",
  #          "172.16.10.128/25"]
  #
  # Returns an array of IPv4 objects
  #
  def split(subnets = 2)
    unless (1..size).include?(subnets)
      raise ArgumentError, "Value #{subnets} out of range"
    end

    networks = subnet(prefix + Math.log2(subnets).ceil)

    until networks.size == subnets
      networks.reverse!.each_with_index { |n, i|
        if s = n.proper_supernet(networks[i + 1])
          networks[i, 2] = s
          break
        end
      }

      networks.reverse!
    end

    networks
  end

  alias_method :/, :split

  #
  # Returns a new IPv4 object from the supernetting
  # of the instance network.
  #
  # Supernetting is similar to subnetting, except
  # that you getting as a result a network with a
  # smaller prefix (bigger host space). For example,
  # given the network
  #
  #   ip = IPAddress("172.16.10.0/24")
  #
  # you can supernet it with a new /23 prefix
  #
  #   ip.supernet(23).to_string
  #     #=> "172.16.10.0/23"
  #
  # However if you supernet it with a /22 prefix, the
  # network address will change:
  #
  #   ip.supernet(22).to_string
  #     #=> "172.16.8.0/22"
  #
  # If +new_prefix+ is less than 1, returns 0.0.0.0/0
  #
  def supernet(num, relax = false)
    superprefix = prefix.superprefix(num, relax)
    new_prefix(superprefix).network if superprefix
  end

  def exact_supernet(*other)
    s = supernet(prefix - 1)
    s if s.include_exactly?(self, *other)
  end

  def proper_supernet(*other)
    include_all?(*other) ? self : exact_supernet(*other)
  end

  #
  # This method implements the subnetting function
  # similar to the one described in RFC3531.
  #
  # By specifying a new prefix, the method calculates
  # the network number for the given IPv4 object
  # and calculates the subnets associated to the new
  # prefix.
  #
  # For example, given the following network:
  #
  #   ip = IPAddress("172.16.10.0/24")
  #
  # we can calculate the subnets with a /26 prefix
  #
  #   ip.subnet(26).map { |i| i.to_string }
  #     #=> ["172.16.10.0/26", "172.16.10.64/26",
  #          "172.16.10.128/26", "172.16.10.192/26"]
  #
  # The resulting number of subnets will of course always be
  # a power of two.
  #
  def subnet(num)
    n, m, s = network_i, *prefix.subprefix(num)
    Array.new(s) { |i| self.class.parse_i(n + (i * m), num) }
  end

  #
  # Returns the difference between two IP addresses
  # in unsigned int 32/128 bits format
  #
  # Example:
  #
  #   ip1 = IPAddress("172.16.10.0/24")
  #   ip2 = IPAddress("172.16.11.0/24")
  #
  #   ip1.distance(ip2)
  #     #=> 256
  #
  def distance(other)
    (to_i - other.to_i).abs
  end

  def subtract(*other)
    self.class.subtract(self, *other)
  end

  alias_method :-, :subtract

  #
  # Returns a new IPv4 object which is the result
  # of the summarization, if possible, of the two
  # objects
  #
  # Example:
  #
  #   ip1 = IPAddress("172.16.10.1/24")
  #   ip2 = IPAddress("172.16.11.2/24")
  #
  #   p (ip1 + ip2).map {|i| i.to_string}
  #     #=> ["172.16.10.0/23"]
  #
  # If the networks are not contiguous, returns
  # the two network numbers from the objects
  #
  #   ip1 = IPAddress("10.0.0.1/24")
  #   ip2 = IPAddress("10.0.2.1/24")
  #
  #   p (ip1 + ip2).map {|i| i.to_string}
  #     #=> ["10.0.0.0/24","10.0.2.0/24"]
  #
  def summarize(other)
    self.class.summarize(self, other)
  end

  alias_method :+, :summarize

  def range(other)
    raise TypeError, 'must be same version' if other.version != version

    return [self] unless other > self

    nets, n, l, m = [], to_i, other.to_i, self.class::MAX_PREFIX

    until n > l
      i = self.class.parse_i(n, m)
      f = i.bits.rindex('1') || -1

      while s = i.supernet(f += 1, true)
        unless s.broadcast_i > l
          i = s
          break
        end
      end

      nets << i
      n = i.broadcast_i + 1
    end

    nets
  end

  def span
    lazy_attr(:span) { network_i..broadcast_i }
  end

  def span_i
    lazy_attr(:span_i) { span.to_a }
  end

  def boundaries
    lazy_attr(:boundaries) { [(s = span).first, s.last] }
  end

  def each_i(first = nil, last = nil)
    f, l = boundaries
    [first || f, f].max.upto([last || l, l].min) { |i| yield i }
    self
  end

  #
  # Iterates over all the IP addresses for the given
  # network (or IP address).
  #
  # The object yielded is a new IPv4/IPv6 object created
  # from the iteration.
  #
  #   ip = IPAddress("10.0.0.1/29")
  #
  #   ip.each do |i|
  #     p i.address
  #   end
  #     #=> "10.0.0.0"
  #     #=> "10.0.0.1"
  #     #=> "10.0.0.2"
  #     #=> "10.0.0.3"
  #     #=> "10.0.0.4"
  #     #=> "10.0.0.5"
  #     #=> "10.0.0.6"
  #     #=> "10.0.0.7"
  #
  #   ip6 = IPAddress("2001:db8::4/125")
  #
  #   ip6.each do |i|
  #     p i.compressed
  #   end
  #     #=> "2001:db8::"
  #     #=> "2001:db8::1"
  #     #=> "2001:db8::2"
  #     #=> "2001:db8::3"
  #     #=> "2001:db8::4"
  #     #=> "2001:db8::5"
  #     #=> "2001:db8::6"
  #     #=> "2001:db8::7"
  #
  # WARNING: if the host portion is very large, this method
  # can be very slow and possibly hang your system!
  #
  def each(*args)
    f = prefix
    each_i(*args) { |i| yield self.class.parse_i(i, f) }
  end

  #
  # Iterates over all the hosts IP addresses for the given
  # network (or IP address).
  #
  #   ip = IPAddress("10.0.0.1/29")
  #
  #   ip.each_host do |i|
  #     p i.to_s
  #   end
  #     #=> "10.0.0.1"
  #     #=> "10.0.0.2"
  #     #=> "10.0.0.3"
  #     #=> "10.0.0.4"
  #     #=> "10.0.0.5"
  #     #=> "10.0.0.6"
  #
  def each_host
    f, l = boundaries
    each(f + 1, l - 1) { |i| yield i }
  end

  def at(index)
    s = span

    index += index < 0 ? s.last + 1 : s.first
    each(index) { |i| return i } if s.include?(index)

    nil
  end

  #
  # Returns a new IPv4/IPv6 object with the
  # first host IP address in the range.
  #
  # Example: given the 192.168.100.0/24 network, the first
  # host IP address is 192.168.100.1.
  #
  #   ip = IPAddress("192.168.100.0/24")
  #
  #   ip.first.to_s
  #     #=> "192.168.100.1"
  #
  # The object IP doesn't need to be a network: the method
  # automatically gets the network number from it
  #
  #   ip = IPAddress("192.168.100.50/24")
  #
  #   ip.first.to_s
  #     #=> "192.168.100.1"
  #
  def first
    lazy_attr(:first, false) { at(1) }
  end

  #
  # Like its sibling method IPv4#first/IPv6#first, this method
  # returns a new IPv4/IPv6 object with the
  # last host IP address in the range.
  #
  # Example: given the 192.168.100.0/24 network, the last
  # host IP address is 192.168.100.254
  #
  #   ip = IPAddress("192.168.100.0/24")
  #
  #   ip.last.to_s
  #     #=> "192.168.100.254"
  #
  # The object IP doesn't need to be a network: the method
  # automatically gets the network number from it
  #
  #   ip = IPAddress("192.168.100.50/24")
  #
  #   ip.last.to_s
  #     #=> "192.168.100.254"
  #
  def last
    lazy_attr(:last, false) { at(-2) }
  end

  def succ
    lazy_attr(:succ, false) { self.class.parse_i(to_i + 1, prefix) }
  end

  #
  # Returns an array with the IP addresses of
  # all the hosts in the network.
  #
  #   ip = IPAddress("10.0.0.1/29")
  #
  #   ip.hosts.map { |i| i.address }
  #     #=> ["10.0.0.1",
  #     #=>  "10.0.0.2",
  #     #=>  "10.0.0.3",
  #     #=>  "10.0.0.4",
  #     #=>  "10.0.0.5",
  #     #=>  "10.0.0.6"]
  #
  def hosts
    lazy_attr(:hosts) { hosts = []; each_host { |i| hosts << i }; hosts }
  end

  def mapped
    IPv6::Mapped.new(to_string) if ipv4? || mapped?
  end

  #
  # Spaceship operator to compare IPv4/IPv6 objects
  #
  # Comparing IPv4/IPv6 addresses is useful to ordinate
  # them into lists that match our intuitive
  # perception of ordered IP addresses.
  #
  # The first comparison criteria is the u32/u128 value.
  # For example, 10.100.100.1 will be considered
  # to be less than 172.16.0.1, because, in a ordered list,
  # we expect 10.100.100.1 to come before 172.16.0.1;
  # 2001:db8:1::1 will be considered
  # to be less than 2001:db8:2::1, because, in a ordered list,
  # we expect 2001:db8:1::1 to come before 2001:db8:2::1.
  #
  # The second criteria, in case two IPv4/IPv6 objects
  # have identical addresses, is the prefix. A higher
  # prefix will be considered greater than a lower
  # prefix. This is because we expect to see
  # 10.100.100.0/24 come before 10.100.100.0/25;
  # 2001:db8:1::1/64 before 2001:db8:1::1/65.
  #
  # Example:
  #
  #   ip1 = IPAddress("10.100.100.1/8")
  #   ip2 = IPAddress("172.16.0.1/16")
  #   ip3 = IPAddress("10.100.100.1/16")
  #
  #   ip1 < ip2
  #     #=> true
  #   ip1 > ip3
  #     #=> false
  #
  #   [ip1,ip2,ip3].sort.map { |i| i.to_string }
  #     #=> ["10.100.100.1/8","10.100.100.1/16","172.16.0.1/16"]
  #
  #   ip1 = IPAddress("2001:db8:1::1/64")
  #   ip2 = IPAddress("2001:db8:2::1/64")
  #   ip3 = IPAddress("2001:db8:1::1/65")
  #
  #   ip1 < ip2
  #     #=> true
  #   ip1 < ip3
  #     #=> false
  #
  #   [ip1,ip2,ip3].sort.map { |i| i.to_string }
  #     #=> ["2001:db8:1::1/64","2001:db8:1::1/65","2001:db8:2::1/64"]
  #
  def <=>(other)
    [to_i, prefix] <=> [other.to_i, other.prefix]
  end

  def hash
    lazy_attr(:hash) { [to_i, prefix.hash].hash }
  end

  alias_method :eql?, :==

  private

  def split_ip_and_netmask(str, validate = true)
    ip_and_netmask = str.split('/')

    if validate && !self.class.valid_ip?(ip = ip_and_netmask.first)
      raise ArgumentError, "Invalid IP #{ip.inspect}"
    else
      ip_and_netmask
    end
  end

end

#
# IPAddress is a wrapper method built around
# IPAddress's library classes. Its purpose is to
# make you independent from the type of IP address
# you're going to use.
#
# For example, instead of creating the three types
# of IP addresses using their own contructors
#
#   ip  = IPAddress::IPv4.new "172.16.10.1/24"
#   ip6 = IPAddress::IPv6.new "2001:db8::8:800:200c:417a/64"
#   ip_mapped = IPAddress::IPv6::Mapped "::ffff:172.16.10.1/128"
#
# you can just use the IPAddress wrapper:
#
#   ip  = IPAddress "172.16.10.1/24"
#   ip6 = IPAddress "2001:db8::8:800:200c:417a/64"
#   ip_mapped = IPAddress "::ffff:172.16.10.1/128"
#
# All the objects created will be instances of the
# correct class:
#
#  ip.class
#    #=> IPAddress::IPv4
#  ip6.class
#    #=> IPAddress::IPv6
#  ip_mapped.class
#    #=> IPAddress::IPv6::Mapped
#
def IPAddress(str)
  IPAddress.parse(str)
end

#
# Compatibility with Ruby 1.8
#
if RUBY_VERSION < '1.9'
  def Math.log2(n)  # :nodoc:
    log(n) / log(2)
  end
end

require 'ipaddress/prefix'

require 'ipaddress/ipv4'
require 'ipaddress/ipv6'
