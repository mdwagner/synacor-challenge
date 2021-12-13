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
    MAX_U15 = (2 ** 15).to_u16

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

      i = 0
      while i < @memory.size
        i = run_opcode(@memory[i], i)
        # run_opcode(opcode: @memory[i], index: i) # index == opcode value

        # TODO
        # i = handle_opcode(i)
        # i == opcode index, use @memory for access
        # handle_opcode : next opcode index
      end

      #pp! @memory[0..10]
      #pp! @memory.size
    end

    def run_opcode(opcode : UInt16, index : Int32) : Int32
      # TODO: convert opcode to enum
      case opcode
      when 0_u16
        puts "=== HALT ==="
        exit
      when 19_u16
        puts "=== OUT ==="
        next_index = index + 1
        next_value = get_value(@memory[next_index])
        get_string(next_value)
        next_index
      when 21_u16
        puts "=== NOOP ==="
        index + 1
      else
        puts opcode
        index + 1
      end
    end

    def get_value(value : UInt16) : UInt16
      if value > 32775_u16
        # invalid
        puts "FAIL"
        exit
      end

      n = (value % MAX_U15)
      if n < 8
        # reg
        puts "CAME FROM REG #{n}"
        @registers[n]
      else
        # normal
        puts "NORMAL VALUE"
        value
      end
    end

    def get_string(value : UInt16)
      pp! value.unsafe_chr
      #slice = Bytes.new(2)
      #IO::ByteFormat::LittleEndian.encode(value, slice)
      #str = String.new(slice)
      #pp! str.valid_encoding?
      #pp! str.chars
      #str
    end
  end
end
