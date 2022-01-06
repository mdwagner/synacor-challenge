module SynacorChallenge
  MAX_VALUE     = (2 ** 15).to_u16
  INVALID_VALUE = MAX_VALUE + 8
  REGISTERS     = MAX_VALUE...INVALID_VALUE

  # binary format
  # each number is stored as a 16-bit little-endian pair (low byte, high byte)
  # numbers 0..32767 mean a literal value
  # numbers 32768..32775 instead mean registers 0..7
  # numbers 32776..65535 are invalid
  # programs are loaded into memory starting at address 0
  # address 0 is the first 16-bit value, address 1 is the second 16-bit value, etc
  class SynacorVM
    # memory with 15-bit address space storing 16-bit values
    getter memory = Array(UInt16).new(2 ** 15)

    # eight registers
    getter registers = StaticArray(UInt16, 8).new(0)

    # unbounded stack which holds individual 16-bit values
    getter stack = Array(UInt16).new

    # program counter
    @pc = 0

    property input_buffer = Deque(Char).new

    property stdin : IO = STDIN

    property stdout : IO = STDOUT

    def initialize(io : IO)
      slice = Bytes.new(2)
      while (bytes_read = io.read(slice)) != 0
        break if bytes_read != 2
        @memory << IO::ByteFormat::LittleEndian.decode(UInt16, slice)
      end
    end

    def main : Nil
      @pc = 0
      while @pc < @memory.size
        if opcode = OpCode.from_value?(@memory[@pc])
          execute_opcode(opcode)
        else
          @pc += 1
        end
      end
    end

    def get_raw_value(value : UInt16) : UInt16
      if value >= INVALID_VALUE
        raise InvalidValueException.new
      elsif REGISTERS.includes?(value)
        @registers[value % MAX_VALUE]
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

    private def get_args_pc_values(arg_count : Int32) : Array(Int32)
      args = [] of Int32
      arg_count.times do |n|
        args << @pc + (n + 1)
      end
      args
    end

    private def execute_opcode(opcode : OpCode)
      {% begin %}
        case opcode
      {% for x in OpCode.constants.map(&.downcase.underscore) %}
        in .{{x.id}}?
          op_{{x.id}}
      {% end %}
        end
      {% end %}
    end

    private def op_halt
      raise HaltException.new
    end

    private def op_set
      arg1, arg2 = get_args_pc_values(2)

      reg = get_register(@memory[arg1])
      value = get_raw_value(@memory[arg2])

      @registers[reg] = value

      @pc += 3
    end

    private def op_push
      arg1 = get_args_pc_values(1).first

      value = get_raw_value(@memory[arg1])

      @stack << value

      @pc += 2
    end

    private def op_pop
      if value = @stack.pop?
        arg1 = get_args_pc_values(1).first

        reg = get_register(@memory[arg1])

        @registers[reg] = value
      else
        raise StackEmptyException.new
      end

      @pc += 2
    end

    private def op_eq
      arg1, arg2, arg3 = get_args_pc_values(3)

      reg = get_register(@memory[arg1])
      a = get_raw_value(@memory[arg2])
      b = get_raw_value(@memory[arg3])

      if a == b
        @registers[reg] = 1_u16
      else
        @registers[reg] = 0_u16
      end

      @pc += 4
    end

    private def op_gt
      arg1, arg2, arg3 = get_args_pc_values(3)

      reg = get_register(@memory[arg1])
      a = get_raw_value(@memory[arg2])
      b = get_raw_value(@memory[arg3])

      if a > b
        @registers[reg] = 1_u16
      else
        @registers[reg] = 0_u16
      end

      @pc += 4
    end

    private def op_jmp
      arg1 = get_args_pc_values(1).first

      @pc = get_raw_value(@memory[arg1]).to_i32
    end

    private def op_jt
      arg1, arg2 = get_args_pc_values(2)

      if get_raw_value(@memory[arg1]) != 0_u16
        @pc = get_raw_value(@memory[arg2]).to_i32
      else
        @pc += 3
      end
    end

    private def op_jf
      arg1, arg2 = get_args_pc_values(2)

      if get_raw_value(@memory[arg1]) == 0_u16
        @pc = get_raw_value(@memory[arg2]).to_i32
      else
        @pc += 3
      end
    end

    private def op_add
      arg1, arg2, arg3 = get_args_pc_values(3)

      reg = get_register(@memory[arg1])
      a = get_raw_value(@memory[arg2])
      b = get_raw_value(@memory[arg3])

      @registers[reg] = (a + b) % MAX_VALUE

      @pc += 4
    end

    private def op_mult
      arg1, arg2, arg3 = get_args_pc_values(3)

      reg = get_register(@memory[arg1])
      a = get_raw_value(@memory[arg2])
      b = get_raw_value(@memory[arg3])

      value = (a.to_u64 * b.to_u64) % MAX_VALUE.to_u64
      @registers[reg] = value.to_u16

      @pc += 4
    end

    private def op_mod
      arg1, arg2, arg3 = get_args_pc_values(3)

      reg = get_register(@memory[arg1])
      a = get_raw_value(@memory[arg2])
      b = get_raw_value(@memory[arg3])

      @registers[reg] = a % b

      @pc += 4
    end

    private def op_and
      arg1, arg2, arg3 = get_args_pc_values(3)

      reg = get_register(@memory[arg1])
      a = get_raw_value(@memory[arg2])
      b = get_raw_value(@memory[arg3])

      @registers[reg] = a & b

      @pc += 4
    end

    private def op_or
      arg1, arg2, arg3 = get_args_pc_values(3)

      reg = get_register(@memory[arg1])
      a = get_raw_value(@memory[arg2])
      b = get_raw_value(@memory[arg3])

      @registers[reg] = a | b

      @pc += 4
    end

    private def op_not
      arg1, arg2 = get_args_pc_values(2)

      reg = get_register(@memory[arg1])
      value = get_raw_value(@memory[arg2])

      @registers[reg] = (MAX_VALUE - 1) - value

      @pc += 3
    end

    private def op_rmem
      arg1, arg2 = get_args_pc_values(2)

      reg = get_register(@memory[arg1])
      address = get_raw_value(@memory[arg2])

      value = @memory[address]

      @registers[reg] = value

      @pc += 3
    end

    private def op_wmem
      arg1, arg2 = get_args_pc_values(2)

      address = get_raw_value(@memory[arg1])
      value = get_raw_value(@memory[arg2])

      @memory[address] = value

      @pc += 3
    end

    private def op_call
      arg1, next_pos = get_args_pc_values(2)

      @stack << next_pos.to_u16

      @pc = get_raw_value(@memory[arg1]).to_i32
    end

    private def op_ret
      if value = @stack.pop?
        @pc = value.to_i32
      else
        raise HaltException.new
      end
    end

    private def op_out
      arg1 = get_args_pc_values(1).first

      value = get_raw_value(@memory[arg1])

      @stdout << value.chr.to_s

      @pc += 2
    end

    private def op_in
      arg1 = get_args_pc_values(1).first

      reg = get_register(@memory[arg1])

      if chr = @input_buffer.shift?
        @registers[reg] = chr.ord.to_u16
      else
        @stdin.gets(chomp: false).try do |input|
          if input.starts_with?("$debug")
            # DEBUG MODE
            # starts "repl" until $exit is called
            #   $r{0,7} = print value of reg <value>
            #   $s = print stack
            #   $m = print last 10 and future 10 memory addresses
            puts "Started DEBUG Mode"
            debug = true
            while debug
              @stdin.gets.try do |cmd|
                if cmd == "$exit"
                  debug = false
                  break
                end

                if match = cmd.match(/\$r(\d+)/)
                  matched_reg = match[1].to_i
                  unless (0..7).includes?(matched_reg)
                    puts "Unrecognized command"
                    next
                  end
                  puts "REGISTER #{matched_reg} => #{@registers[matched_reg]}"
                elsif cmd == "$r"
                  puts "REGISTERS => #{@registers}"
                elsif cmd == "$s"
                  puts "STACK => #{@stack}"
                elsif cmd == "$m"
                  puts "MEMORY => #{@memory[(@pc - 10)..(@pc + 10)]}"
                else
                  puts "Unrecognized command"
                end
              end
            end
            puts "Left DEBUG Mode"
          else
            @input_buffer.concat input.chars
            return op_in
          end
        end
        @registers[reg] = '\n'.ord.to_u16
      end

      @pc += 2
    end

    private def op_noop
      @pc += 1
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

  class HaltException < Exception; end

  class InvalidValueException < Exception; end

  class StackEmptyException < Exception; end
end
