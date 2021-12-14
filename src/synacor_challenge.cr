struct UInt16
  MAX_U15 = (2 ** 15).to_u16

  def add_u15(other : UInt16)
    ((self + other) % MAX_U15).to_u16
  end

  def mul_u15(other : UInt16)
    ((self * other) % MAX_U15).to_u16
  end
end

module SynacorChallenge
  class VM
    # bytes to read into memory (one-time use)
    @io : IO

    # STDOUT IO redirect (testing)
    @stdout : IO
    # STDIN IO redirect (testing)
    @stdin : IO
    # STDERR IO redirect (testing)
    @stderr : IO

    # NOTE memory with 15-bit address space storing 16-bit values
    @memory = Array(UInt16).new(2 ** 15)

    # NOTE eight registers
    @registers = uninitialized UInt16[8]

    # NOTE unbounded stack which holds individual 16-bit values
    @stack = Array(UInt16).new

    # binary format
    # each number is stored as a 16-bit little-endian pair (low byte, high byte)
    # numbers 0..32767 mean a literal value
    # numbers 32768..32775 instead mean registers 0..7
    # numbers 32776..65535 are invalid
    # programs are loaded into memory starting at address 0
    # address 0 is the first 16-bit value, address 1 is the second 16-bit value, etc

    def initialize(@io, @stdout = STDOUT, @stdin = STDIN, @stderr = STDERR)
    end

    def main : Int32
      # load program into @memory
      load_io

      # start program
      index = 0
      while index < @memory.size
        index = handle_opcode(index)
      end

      # exit safely
      0
    rescue HaltProgramException
      # program halted
      -1
    end

    def load_io : Nil
      slice = Bytes.new(2)
      while (bytes_read = @io.read(slice)) != 0
        break if bytes_read != 2
        @memory << IO::ByteFormat::LittleEndian.decode(UInt16, slice)
      end
    end

    def handle_opcode(index : Int32) : Int32
      opcode = OpCode.from_value?(@memory[index])

      if opcode.nil?
        puts "<#{@memory[index]}>"
        index + 1
      else
        case opcode
        in .halt_program?
          raise HaltProgramException.new
        in .set_value?
          index + 3
        in .push?
          index + 2
        in .pop_write?
          index + 2
        in .equal_to?
          index + 4
        in .greater_than?
          index + 4
        in .jump_to?
          index + 2
        in .jump_to_if_true?
          index + 3
        in .jump_to_if_false?
          index + 3
        in .add?
          index + 4
        in .mult?
          index + 4
        in .mod?
          index + 4
        in .bitwise_and?
          index + 4
        in .bitwise_or?
          index + 4
        in .bitwise_not?
          index + 3
        in .read_memory?
          index + 3
        in .write_memory?
          index + 3
        in .call?
          index + 2
        in .pop_return?
          index + 1
        in .std_out?
          opcode_std_out(index)
        in .std_in?
          index + 2
        in .noop?
          opcode_noop(index)
        end
      end
    end

    private def get_value(value : UInt16) : UInt16
      if value > 32775_u16
        raise InvalidValueException.new
      end

      n = (value % UInt16::MAX_U15)
      if n < 8
        @registers[n]
      else
        value
      end
    end

    private def opcode_std_out(index)
      arg_pos = index + 1
      value = get_value(@memory[arg_pos])
      @stdout << value.chr.to_s

      index + 2
    end

    private def opcode_noop(index)
      index + 1
    end
  end

  enum OpCode : UInt16
    HaltProgram
    SetValue
    Push
    PopWrite
    EqualTo
    GreaterThan
    JumpTo
    JumpToIfTrue
    JumpToIfFalse
    Add
    Mult
    Mod
    BitwiseAnd
    BitwiseOr
    BitwiseNot
    ReadMemory
    WriteMemory
    Call
    PopReturn
    StdOut
    StdIn
    Noop
  end

  class HaltProgramException < Exception
  end

  class InvalidValueException < Exception
  end
end
