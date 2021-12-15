module SynacorChallenge
  class VM
    MAX_VALUE      = (2 ** 15).to_u16
    INVALID_VALUE = MAX_VALUE + 7
    REGISTER_RANGE = MAX_VALUE..INVALID_VALUE

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

    def initialize(io : IO, @stdout = STDOUT, @stdin = STDIN, @stderr = STDERR)
      slice = Bytes.new(2)
      while (bytes_read = io.read(slice)) != 0
        break if bytes_read != 2
        @memory << IO::ByteFormat::LittleEndian.decode(UInt16, slice)
      end
    end

    def main : Int32
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

    def handle_opcode(index : Int32) : Int32
      case (opcode = OpCode.from_value?(@memory[index]))
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
        opcode_jmp(index)
      in .jt?
        opcode_jt(index)
      in .jf?
        opcode_jf(index)
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
    # Raises `InvalidValueException` if *value* is over INVALID_VALUE.
    private def get_raw_value(value : UInt16) : UInt16
      if value > INVALID_VALUE
        raise InvalidValueException.new
      elsif REGISTER_RANGE.includes?(value)
        @registers[value % MAX_VALUE]
      else
        value
      end
    end

    private def opcode_jmp(index)
      arg_pos = index + 1
      jmp_index = get_raw_value(@memory[arg_pos])
      jmp_index.to_i32
    end

    private def opcode_jt(index)
      arg1_pos = index + 1
      arg2_pos = index + 2

      arg1_value = get_raw_value(@memory[arg1_pos])

      if arg1_value != 0_u16
        jmp_index = get_raw_value(@memory[arg2_pos])
        jmp_index.to_i32
      else
        index + 3
      end
    end

    private def opcode_jf(index)
      arg1_pos = index + 1
      arg2_pos = index + 2

      arg1_value = get_raw_value(@memory[arg1_pos])

      if arg1_value == 0_u16
        jmp_index = get_raw_value(@memory[arg2_pos])
        jmp_index.to_i32
      else
        index + 3
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

    def to_u16
      self.value.to_u16
    end
  end

  class HaltException < Exception
  end

  class InvalidValueException < Exception
  end
end
