# struct UInt16
# MAX_U15 = (2 ** 15).to_u16
# def add_u15(other : UInt16)
# ((self + other) % MAX_U15).to_u16
# end
# def mul_u15(other : UInt16)
# ((self * other) % MAX_U15).to_u16
# end
# end

module SynacorChallenge
  class VM
    # file: challenge.bin in read-only binary mode
    @io : IO

    # TODO: memory with 15-bit address space storing 16-bit values
    @memory = Array(UInt16).new(2 ** 15)

    # TODO: eight registers
    @registers = uninitialized UInt16[8]

    # TODO: unbounded stack which holds individual 16-bit values
    @stack = Array(UInt16).new

    # binary format
    # each number is stored as a 16-bit little-endian pair (low byte, high byte)
    # numbers 0..32767 mean a literal value
    # numbers 32768..32775 instead mean registers 0..7
    # numbers 32776..65535 are invalid
    # programs are loaded into memory starting at address 0
    # address 0 is the first 16-bit value, address 1 is the second 16-bit value, etc

    def initialize(@io)
    end

    def main
      slice = Bytes.new(2)
      while @io.read_fully?(slice)
        @memory << IO::ByteFormat::LittleEndian.decode(UInt16, slice)
      end

      pp! @memory[0..10]
      pp! @memory.size
    end
  end
end
