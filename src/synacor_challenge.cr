require "./vm"

module SynacorChallenge
  MAX_VALUE     = (2 ** 15).to_u16
  INVALID_VALUE = MAX_VALUE + 8
  REGISTERS     = MAX_VALUE...INVALID_VALUE

  class SynacorVM < VM
    # STDOUT IO redirect (testing)
    property stdout : IO
    # STDIN IO redirect (testing)
    property stdin : IO
    # STDERR IO redirect (testing)
    property stderr : IO

    # NOTE memory with 15-bit address space storing 16-bit values
    getter memory : Array(UInt16)

    # NOTE eight registers
    getter register : StaticArray(UInt16, 8)

    # NOTE unbounded stack which holds individual 16-bit values
    getter stack : Array(UInt16)

    property save_file = Deque(Char).new

    # binary format
    # each number is stored as a 16-bit little-endian pair (low byte, high byte)
    # numbers 0..32767 mean a literal value
    # numbers 32768..32775 instead mean registers 0..7
    # numbers 32776..65535 are invalid
    # programs are loaded into memory starting at address 0
    # address 0 is the first 16-bit value, address 1 is the second 16-bit value, etc

    def initialize(io : IO, @stdout = STDOUT, @stdin = STDIN, @stderr = STDERR)
      @memory = Array(UInt16).new(2 ** 15)
      @register = StaticArray(UInt16, 8).new(0)
      @stack = Array(UInt16).new

      slice = Bytes.new(2)
      while (bytes_read = io.read(slice)) != 0
        break if bytes_read != 2
        @memory << IO::ByteFormat::LittleEndian.decode(UInt16, slice)
      end
    end

    def main : Status
      run do
        if op = OpCode.from_value?(current_value)
          op.execute(self)
        else
          @pos += 1
        end
      end

      Status::Ok
    rescue HaltException
      Status::Halt
    rescue InvalidValueException
      Status::InvalidValue
    rescue err
      err.inspect_with_backtrace(stderr)
      Status::Error
    end

    def get_raw_value(value : UInt16) : UInt16
      if value >= INVALID_VALUE
        raise InvalidValueException.new
      elsif REGISTERS.includes?(value)
        register[value % MAX_VALUE]
      else
        value
      end
    end

    def get_register(value : UInt16) : Int32
      if REGISTERS.includes?(value)
        (value % MAX_VALUE).to_i32
      else
        raise InvalidValueException.new
      end
    end

    def get_args_pos(arg_count : Int32) : Array(Int32)
      args = [] of Int32
      arg_count.times do |n|
        args << @pos + (n + 1)
      end
      args
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

    def execute(vm : VM) : Nil
      {% begin %}
      {% methods = @type.constants.map(&.downcase.underscore) %}
        case self
      {% for m in methods %}
        in .{{m.id}}?
          op_{{m.id}}(vm)
      {% end %}
        end
      {% end %}
    end

    def op_halt(vm)
      raise HaltException.new
    end

    def op_set(vm)
      arg1, arg2 = vm.get_args_pos(2)

      reg = vm.get_register(vm.memory[arg1])
      value = vm.get_raw_value(vm.memory[arg2])

      vm.register[reg] = value

      vm.pos += 3
    end

    def op_push(vm)
      arg = vm.get_args_pos(1).first

      value = vm.get_raw_value(vm.memory[arg])

      vm.stack << value

      vm.pos += 2
    end

    def op_pop(vm)
      if (value = vm.stack.pop?)
        arg = vm.get_args_pos(1).first

        reg = vm.get_register(vm.memory[arg])

        vm.register[reg] = value
      else
        raise StackEmptyException.new
      end

      vm.pos += 2
    end

    def op_eq(vm)
      arg1, arg2, arg3 = vm.get_args_pos(3)

      reg = vm.get_register(vm.memory[arg1])
      a = vm.get_raw_value(vm.memory[arg2])
      b = vm.get_raw_value(vm.memory[arg3])

      if a == b
        vm.register[reg] = 1_u16
      else
        vm.register[reg] = 0_u16
      end

      vm.pos += 4
    end

    def op_gt(vm)
      arg1, arg2, arg3 = vm.get_args_pos(3)

      reg = vm.get_register(vm.memory[arg1])
      a = vm.get_raw_value(vm.memory[arg2])
      b = vm.get_raw_value(vm.memory[arg3])

      if a > b
        vm.register[reg] = 1_u16
      else
        vm.register[reg] = 0_u16
      end

      vm.pos += 4
    end

    def op_jmp(vm)
      arg = vm.get_args_pos(1).first

      vm.pos = vm.get_raw_value(vm.memory[arg]).to_i32
    end

    def op_jt(vm)
      arg1, arg2 = vm.get_args_pos(2)

      if vm.get_raw_value(vm.memory[arg1]) != 0_u16
        vm.pos = vm.get_raw_value(vm.memory[arg2]).to_i32
      else
        vm.pos += 3
      end
    end

    def op_jf(vm)
      arg1, arg2 = vm.get_args_pos(2)

      if vm.get_raw_value(vm.memory[arg1]) == 0_u16
        vm.pos = vm.get_raw_value(vm.memory[arg2]).to_i32
      else
        vm.pos += 3
      end
    end

    def op_add(vm)
      arg1, arg2, arg3 = vm.get_args_pos(3)

      reg = vm.get_register(vm.memory[arg1])
      a = vm.get_raw_value(vm.memory[arg2])
      b = vm.get_raw_value(vm.memory[arg3])

      vm.register[reg] = (a + b) % MAX_VALUE

      vm.pos += 4
    end

    def op_mult(vm)
      arg1, arg2, arg3 = vm.get_args_pos(3)

      reg = vm.get_register(vm.memory[arg1])
      a = vm.get_raw_value(vm.memory[arg2])
      b = vm.get_raw_value(vm.memory[arg3])

      value = (a.to_u64 * b.to_u64) % MAX_VALUE.to_u64
      vm.register[reg] = value.to_u16

      vm.pos += 4
    end

    def op_mod(vm)
      arg1, arg2, arg3 = vm.get_args_pos(3)

      reg = vm.get_register(vm.memory[arg1])
      a = vm.get_raw_value(vm.memory[arg2])
      b = vm.get_raw_value(vm.memory[arg3])

      vm.register[reg] = a % b

      vm.pos += 4
    end

    def op_and(vm)
      arg1, arg2, arg3 = vm.get_args_pos(3)

      reg = vm.get_register(vm.memory[arg1])
      a = vm.get_raw_value(vm.memory[arg2])
      b = vm.get_raw_value(vm.memory[arg3])

      vm.register[reg] = a & b

      vm.pos += 4
    end

    def op_or(vm)
      arg1, arg2, arg3 = vm.get_args_pos(3)

      reg = vm.get_register(vm.memory[arg1])
      a = vm.get_raw_value(vm.memory[arg2])
      b = vm.get_raw_value(vm.memory[arg3])

      vm.register[reg] = a | b

      vm.pos += 4
    end

    def op_not(vm)
      arg1, arg2 = vm.get_args_pos(2)

      reg = vm.get_register(vm.memory[arg1])
      value = vm.get_raw_value(vm.memory[arg2])

      vm.register[reg] = (MAX_VALUE - 1) - value

      vm.pos += 3
    end

    def op_rmem(vm)
      arg1, arg2 = vm.get_args_pos(2)

      reg = vm.get_register(vm.memory[arg1])
      address = vm.get_raw_value(vm.memory[arg2])

      value = vm.memory[address]

      vm.register[reg] = value

      vm.pos += 3
    end

    def op_wmem(vm)
      arg1, arg2 = vm.get_args_pos(2)

      address = vm.get_raw_value(vm.memory[arg1])
      value = vm.get_raw_value(vm.memory[arg2])

      vm.memory[address] = value

      vm.pos += 3
    end

    def op_call(vm)
      arg, next_pos = vm.get_args_pos(2)

      vm.stack << next_pos.to_u16

      vm.pos = vm.get_raw_value(vm.memory[arg]).to_i32
    end

    def op_ret(vm)
      if (value = vm.stack.pop?)
        vm.pos = value.to_i32
      else
        raise HaltException.new
      end
    end

    def op_out(vm)
      arg = vm.get_args_pos(1).first

      value = vm.get_raw_value(vm.memory[arg])

      vm.stdout << value.chr.to_s

      vm.pos += 2
    end

    def op_in(vm)
      arg = vm.get_args_pos(1).first

      reg = vm.get_register(vm.memory[arg])

      if chr = vm.save_file.shift?
        vm.register[reg] = chr.ord.to_u16
      else
        vm.stdin.gets(1).try do |str|
          if chr = str.chars[0]?
            vm.register[reg] = chr.ord.to_u16
          end
        end
      end

      vm.pos += 2
    end

    def op_noop(vm)
      vm.pos += 1
    end
  end

  def self.solve_coin_problem(coin_mapping : Hash(String, Int32)) : Array(String)
    raise "Too many coins" if coin_mapping.size != 5

    solution = [] of Int32

    coin_mapping.values.permutations.each do |values|
      a, b, c, d, e = values
      if a + b * (c ** 2) + (d ** 3) - e == 399
        solution = values
        break
      end
    end

    raise "No solution found" if solution.empty?

    solution.map { |value| coin_mapping.key_for(value) }
  end

  enum Status
    Ok
    Error
    Halt
    InvalidValue
  end

  class HaltException < Exception
  end

  class InvalidValueException < Exception
  end

  class StackEmptyException < Exception
  end
end
