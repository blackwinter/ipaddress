class IPAddress

  module Conversions

    extend self

    def addr2ary(addr)
      addr.split('.').map! { |i| i.to_i }
    end

    def ary2addr(ary)
      ary.join('.')
    end

    def addr2bits(addr)
      data2bits(ary2data(addr2ary(addr)))
    end

    def bits2addr(bits)
      ary2addr([bits].pack('B*').unpack('C4'))
    end

    def data2bits(data)
      data.unpack('B*').first
    end

    def int2addr(int)
      ary2addr(int2ary(int))
    end

    def int2ary(int)
      data2ary(int2data(int))
    end

    def ary2int(ary)
      int = 0
      ary.each_with_index { |i, j| int += i << (3 - j) * 8 }
      int
    end

    def data2ary(data)
      data.unpack('C4').map! { |i| i.to_i }
    end

    def ary2data(ary)
      ary.pack('C4')
    end

    def data2int(data)
      ary2int(data2ary(data))
    end

    def int2data(int)
      [int].pack('N')
    end

  end

end
