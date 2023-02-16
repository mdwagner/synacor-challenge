# binary format
# each number is stored as a 16-bit little-endian pair (low byte, high byte)
# numbers 0..32767 mean a literal value
# numbers 32768..32775 instead mean registers 0..7
# numbers 32776..65535 are invalid
# programs are loaded into memory starting at address 0
# address 0 is the first 16-bit value, address 1 is the second 16-bit value, etc
class Synacor
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

  class HaltError < Exception
  end

  class InvalidValueError < Exception
  end

  class StackEmptyError < Exception
  end

  MAX_VALUE     = (2 ** 15).to_u16
  INVALID_VALUE = MAX_VALUE + 8
  REGISTERS     = MAX_VALUE...INVALID_VALUE

  # memory with 15-bit address space storing 16-bit values
  @memory : StaticArray(UInt16, 32_768)

  # eight registers
  @registers : StaticArray(UInt16, 8)

  # unbounded stack which holds individual 16-bit values
  @stack = Deque(UInt16).new

  # program counter
  @pc = 0

  @values = [] of UInt16

  @buffer = Deque(Char).new

  property stdout : IO = STDOUT
  property stdin : IO = STDIN

  def self.from_file(path : String)
    File.open(path, mode: "rb") do |f|
      new(f)
    end
  end

  def initialize(io : IO)
    @memory = uninitialized StaticArray(UInt16, 32_768)
    @registers = uninitialized StaticArray(UInt16, 8)

    slice = Bytes.new(2)
    index = 0
    while io.read_fully?(slice)
      @memory[index] = IO::ByteFormat::LittleEndian.decode(UInt16, slice)
      index += 1
    end
  end

  def load_save(path : String) : Nil
    save_file = File.read(path).chars
    unless save_file.last(1).includes?('\n')
      save_file << '\n'
    end
    @buffer += Deque(Char).new(save_file)
  end

  def main(restart = false) : Nil
    @pc = 0 if restart
    while @pc < @memory.size
      if opcode = OpCode.from_value?(@memory[@pc])
        execute_opcode(opcode)
      else
        @pc += 1
      end
    end
  rescue HaltError | InvalidValueError | StackEmptyError
    exit 1
  end

  def get(count) : Nil
    @values.clear
    count.times do |index|
      # first value read pc, next values will read n+1
      @pc += 1 if index != 0
      @values << @memory[@pc]
    end
    @pc += 1 # sets up next value to be read
  end

  def fetch_register(value : UInt16) : Int32
    if REGISTERS.includes?(value)
      (value % MAX_VALUE).to_i32
    else
      raise InvalidValueError.new
    end
  end

  def fetch_value(value : UInt16) : UInt16
    if value >= INVALID_VALUE
      raise InvalidValueError.new
    elsif REGISTERS.includes?(value)
      @registers[value % MAX_VALUE]
    else
      value
    end
  end

  def execute_opcode(opcode : OpCode)
    @pc += 1
    {% begin %}
      case opcode
    {% for op_name in OpCode.constants.map(&.underscore) %}
      in .{{op_name.id}}?
        op_{{op_name.id}}
    {% end %}
      end
    {% end %}
  end

  private def op_halt
    raise HaltError.new
  end

  private def op_set
    get(2)
    reg = fetch_register(@values[0])
    value = fetch_value(@values[1])
    @registers[reg] = value
  end

  private def op_push
    get(1)
    value = fetch_value(@values[0])
    @stack << value
  end

  private def op_pop
    if value = @stack.pop?
      values = get(1)
      reg = fetch_register(@values[0])
      @registers[reg] = value
    else
      raise StackEmptyError.new
    end
  end

  private def op_eq
    get(3)
    reg = fetch_register(@values[0])
    a = fetch_value(@values[1])
    b = fetch_value(@values[2])
    @registers[reg] = (a == b) ? 1_u16 : 0_u16
  end

  private def op_gt
    get(3)
    reg = fetch_register(@values[0])
    a = fetch_value(@values[1])
    b = fetch_value(@values[2])
    @registers[reg] = (a > b) ? 1_u16 : 0_u16
  end

  private def op_jmp
    get(1)
    @pc = fetch_value(@values[0]).to_i32
  end

  private def op_jt
    get(2)
    a = fetch_value(@values[0])
    b = fetch_value(@values[1])
    if a != 0_u16
      @pc = b.to_i32
    end
  end

  private def op_jf
    get(2)
    a = fetch_value(@values[0])
    b = fetch_value(@values[1])
    if a == 0_u16
      @pc = b.to_i32
    end
  end

  private def op_add
    get(3)
    reg = fetch_register(@values[0])
    a = fetch_value(@values[1])
    b = fetch_value(@values[2])
    @registers[reg] = (a + b) % MAX_VALUE
  end

  private def op_mult
    get(3)
    reg = fetch_register(@values[0])
    a = fetch_value(@values[1])
    b = fetch_value(@values[2])
    value = (a.to_u64 * b.to_u64) % MAX_VALUE.to_u64
    @registers[reg] = value.to_u16
  end

  private def op_mod
    get(3)
    reg = fetch_register(@values[0])
    a = fetch_value(@values[1])
    b = fetch_value(@values[2])
    @registers[reg] = a % b
  end

  private def op_and
    get(3)
    reg = fetch_register(@values[0])
    a = fetch_value(@values[1])
    b = fetch_value(@values[2])
    @registers[reg] = a & b
  end

  private def op_or
    get(3)
    reg = fetch_register(@values[0])
    a = fetch_value(@values[1])
    b = fetch_value(@values[2])
    @registers[reg] = a | b
  end

  private def op_not
    get(2)
    reg = fetch_register(@values[0])
    value = fetch_value(@values[1])
    @registers[reg] = (MAX_VALUE - 1) - value
  end

  private def op_rmem
    get(2)
    reg = fetch_register(@values[0])
    address = fetch_value(@values[1])
    value = @memory[address]
    @registers[reg] = value
  end

  private def op_wmem
    get(2)
    address = fetch_value(@values[0])
    value = fetch_value(@values[1])
    @memory[address] = value
  end

  private def op_call
    get(1)
    next_op = @pc
    @stack << next_op.to_u16
    a = fetch_value(@values[0])
    @pc = a.to_i32
  end

  private def op_ret
    if value = @stack.pop?
      @pc = value.to_i32
    else
      raise HaltError.new
    end
  end

  private def op_out
    get(1)
    value = fetch_value(@values[0])
    stdout.print value.chr
  end

  private def op_in
    get(1)
    reg = fetch_register(@values[0])

    input_char = if chr = @buffer.shift?
                   chr
                 elsif input = stdin.gets(limit: 1, chomp: false)
                   input.char_at(0)
                 else
                   '\n'
                 end

    @registers[reg] = input_char.ord.to_u16
  end

  private def op_noop
  end

  def self.solve_coin_problem
    coin_mapping = {
      "red"      => 2,
      "blue"     => 9,
      "shiny"    => 5,
      "concave"  => 7,
      "corroded" => 3,
    }
    coin_mapping.values.permutations.each do |coin_values|
      a, b, c, d, e = coin_values
      if a + b * (c ** 2) + (d ** 3) - e == 399
        return coin_values.map { |value| coin_mapping.key_for(value) }
      end
    end
  end
end

# # Program
# - Start normally
# - Load Save file (interpreted commands)
#
# Usage: synacor_challenge [options] [program binary]
# Options:
#   --load-save FILE     Load Save file
##

synacor = Synacor.from_file("#{__DIR__}/../instructions/challenge.bin")
synacor.load_save("#{__DIR__}/../instructions/save1.txt")
synacor.load_save("#{__DIR__}/../instructions/save2.txt")
synacor.main
