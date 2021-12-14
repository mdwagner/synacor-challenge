module SynacorChallenge
  class VM
    MAX_VALUE      = (2 ** 15).to_u16
    REGISTER_RANGE = MAX_VALUE..(MAX_VALUE + 7)

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
    rescue HaltException
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
      case OpCode.from_value?(@memory[index])
      in nil
        index + 1
      in .halt?
        raise HaltException.new
      in .set?
        index + 3
      in .push?
        index + 2
      in .pop?
        index + 2
      in .eq?
        index + 4
      in .gt?
        index + 4
      in .jmp?
        index + 2
      in .jt?
        index + 3
      in .jf?
        index + 3
      in .add?
        index + 4
      in .mult?
        index + 4
      in .mod?
        index + 4
      in .and?
        index + 4
      in .or?
        index + 4
      in .not?
        index + 3
      in .rmem?
        index + 3
      in .wmem?
        index + 3
      in .call?
        index + 2
      in .ret?
        index + 1
      in .out?
        opcode_out(index)
      in .in?
        index + 2
      in .noop?
        index + 1
      end
    end

    # Returns `value` or `@registers[value % MAX_VALUE]`.
    #
    # Raises `InvalidValueException` if *value* is over MAX_VALUE.
    private def get_raw_value(value : UInt16) : UInt16
      if value > MAX_VALUE
        raise InvalidValueException.new
      elsif REGISTER_RANGE.includes?(value)
        @registers[value % MAX_VALUE]
      else
        value
      end
    end

    private def opcode_out(index)
      arg_pos = index + 1
      value = get_raw_value(@memory[arg_pos])
      @stdout << value.chr.to_s

      index + 2
    end
  end

  enum OpCode : UInt16
    Halt
    Set
    Push
    Pop
    Eq
    Gt
    Jmp
    Jt
    Jf
    Add
    Mult
    Mod
    And
    Or
    Not
    Rmem
    Wmem
    Call
    Ret
    Out
    In
    Noop
  end

  class HaltException < Exception
  end

  class InvalidValueException < Exception
  end
end
