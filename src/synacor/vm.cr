class Synacor::VM
  alias ByteFormatLE = IO::ByteFormat::LittleEndian

  MAX_VALUE     = (2 ** 15).to_u16
  INVALID_VALUE = MAX_VALUE + 8
  REGISTERS     = MAX_VALUE...INVALID_VALUE

  # memory with 15-bit address space storing 16-bit values
  property memory : StaticArray(UInt16, 32_768)

  # eight registers
  property registers : StaticArray(UInt16, 8)

  # unbounded stack which holds individual 16-bit values
  property stack : Deque(UInt16)

  # program counter
  property pc = 0

  property input : IO::Memory

  property output : ACON::Output::Interface

  def initialize(@input, @output)
    @memory = uninitialized StaticArray(UInt16, 32_768)
    @registers = uninitialized StaticArray(UInt16, 8)
    @stack = Deque(UInt16).new
  end

  def load(binary_path : String)
    File.open(binary_path, mode: "rb") do |io|
      slice = Bytes.new(2)
      index = 0
      while io.read_fully?(slice)
        self.memory[index] = ByteFormatLE.decode(UInt16, slice)
        index += 1
      end
    end
  end

  def main_loop
    while self.pc < self.memory.size
      if opcode = OpCode.from_value?(self.memory[self.pc])
        case opcode
        in .halt?
          op_halt
        in .set?
          op_set(register_at(1), value_at(2))
        in .push?
          op_push(value_at(1))
        in .pop?
          op_pop(register_at(1))
        in .eq?
          op_eq(register_at(1), value_at(2), value_at(3))
        in .gt?
          op_gt(register_at(1), value_at(2), value_at(3))
        in .jmp?
          op_jmp(value_at(1))
        in .jt?
          op_jt(value_at(1), value_at(2))
        in .jf?
          op_jf(value_at(1), value_at(2))
        in .add?
          op_add(register_at(1), value_at(2), value_at(3))
        in .mult?
          op_mult(register_at(1), value_at(2), value_at(3))
        in .mod?
          op_mod(register_at(1), value_at(2), value_at(3))
        in .and?
          op_and(register_at(1), value_at(2), value_at(3))
        in .or?
          op_or(register_at(1), value_at(2), value_at(3))
        in .not?
          op_not(register_at(1), value_at(2))
        in .rmem?
          op_rmem(register_at(1), value_at(2))
        in .wmem?
          op_wmem(value_at(1), value_at(2))
        in .call?
          op_call(value_at(1))
        in .ret?
          op_ret
        in .out?
          op_out(value_at(1))
        in .in?
          op_in(register_at(1))
        in .noop?
          op_noop
        end
      else
        self.pc += 1
      end
    end
  end

  def to_register(value : UInt16) : Int32
    if REGISTERS.includes?(value)
      (value % MAX_VALUE).to_i
    else
      raise InvalidValueError.new
    end
  end

  def register_at(index : Int32) : Int32
    to_register(self.memory[self.pc + index])
  end

  def to_value(value : UInt16) : UInt16
    if value >= INVALID_VALUE
      raise InvalidValueError.new
    elsif REGISTERS.includes?(value)
      self.registers[value % MAX_VALUE]
    else
      value
    end
  end

  def value_at(index : Int32) : UInt16
    to_value(self.memory[self.pc + index])
  end

  def op_halt
    raise HaltError.new
  end

  def op_set(reg : Int32, value : UInt16)
    self.registers[reg] = value
    self.pc += 3
  end

  def op_push(value : UInt16)
    self.stack << value
    self.pc += 2
  end

  def op_pop(reg : Int32)
    if value = self.stack.pop?
      self.registers[reg] = value
      self.pc += 2
    else
      raise StackEmptyError.new
    end
  end

  def op_eq(reg : Int32, a : UInt16, b : UInt16)
    self.registers[reg] = (a == b) ? 1_u16 : 0_u16
    self.pc += 4
  end

  def op_gt(reg : Int32, a : UInt16, b : UInt16)
    self.registers[reg] = (a > b) ? 1_u16 : 0_u16
    self.pc += 4
  end

  def op_jmp(value : UInt16)
    self.pc = value.to_i
  end

  def op_jt(a : UInt16, b : UInt16)
    if a != 0_u16
      self.pc = b.to_i
    else
      self.pc += 3
    end
  end

  def op_jf(a : UInt16, b : UInt16)
    if a == 0_u16
      self.pc = b.to_i
    else
      self.pc += 3
    end
  end

  def op_add(reg : Int32, a : UInt16, b : UInt16)
    self.registers[reg] = (a + b) % MAX_VALUE
    self.pc += 4
  end

  def op_mult(reg : Int32, a : UInt16, b : UInt16)
    self.registers[reg] = ((a.to_u64 * b.to_u64) % MAX_VALUE.to_u64).to_u16
    self.pc += 4
  end

  def op_mod(reg : Int32, a : UInt16, b : UInt16)
    self.registers[reg] = a % b
    self.pc += 4
  end

  def op_and(reg : Int32, a : UInt16, b : UInt16)
    self.registers[reg] = a & b
    self.pc += 4
  end

  def op_or(reg : Int32, a : UInt16, b : UInt16)
    self.registers[reg] = a | b
    self.pc += 4
  end

  def op_not(reg : Int32, value : UInt16)
    self.registers[reg] = (MAX_VALUE - 1) - value
    self.pc += 3
  end

  def op_rmem(reg : Int32, addr : UInt16)
    self.registers[reg] = self.memory[addr.to_i]
    self.pc += 3
  end

  def op_wmem(addr : UInt16, value : UInt16)
    self.memory[addr.to_i] = value
    self.pc += 3
  end

  def op_call(a : UInt16)
    self.stack << (self.pc + 2).to_u16
    self.pc = a.to_i
  end

  def op_ret
    if value = self.stack.pop?
      self.pc = value.to_i
    else
      raise HaltError.new
    end
  end

  def op_out(value : UInt16)
    self.output.print(value.chr)
    self.pc += 2
  end

  def op_in(reg : Int32)
    if buffered_char = self.input.read_char
      self.output.print(buffered_char)
      self.registers[reg] = buffered_char.ord.to_u16
    elsif input_char = STDIN.read_char
      self.registers[reg] = input_char.ord.to_u16
    else
      self.registers[reg] = '\n'.ord.to_u16
    end
    self.pc += 2
  end

  def op_noop
    self.pc += 1
  end
end
