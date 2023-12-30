module Synacor
  class RunCommand < ACON::Command
    MAX_VALUE     = (2 ** 15).to_u16
    INVALID_VALUE = MAX_VALUE + 8
    REGISTERS     = MAX_VALUE...INVALID_VALUE

    # memory with 15-bit address space storing 16-bit values
    @memory = uninitialized StaticArray(UInt16, 32_768)

    # eight registers
    @registers = uninitialized StaticArray(UInt16, 8)

    # unbounded stack which holds individual 16-bit values
    @stack = Deque(UInt16).new

    # program counter
    @pc = 0

    property line_buffer = Deque(Char).new
    property line_cache = ""
    property? reading_buffer = false

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

    def configure : Nil
      name("run")
      argument("binary", :optional, "Synacor program challenge.bin")
      option("load", "l", ACON::Input::Option::Value[:optional, :is_array])
    end

    def setup(input : ACON::Input::Interface, output : ACON::Output::Interface) : Nil
      binary_path = input.argument("binary", String?) || "#{__DIR__}/../../instructions/challenge.bin"

      File.open(binary_path, mode: "rb") do |f|
        slice = Bytes.new(2)
        index = 0
        while f.read_fully?(slice)
          @memory[index] = IO::ByteFormat::LittleEndian.decode(UInt16, slice)
          index += 1
        end
      end

      input.option("load", Array(String)).each do |save_path|
        save_file = File.read(save_path).chars
        unless save_file.last(1).includes?('\n')
          save_file << '\n'
        end
        self.line_buffer += Deque(Char).new(save_file)
      end
    end

    def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
      @pc = 0
      while @pc < @memory.size
        value = @pc
        @pc += 1
        if opcode = OpCode.from_value?(@memory[value])
          {% begin %}
            case opcode
            {% for op_name in OpCode.constants.map(&.underscore) %}
              in .{{op_name.id}}?
                {% if %w[out in].includes?(op_name.stringify) %}
                  op_{{op_name.id}}(output)
                {% else %}
                  op_{{op_name.id}}
                {% end %}
            {% end %}
            end
          {% end %}
        end
      end
      ACON::Command::Status::SUCCESS
    rescue err : HaltError | InvalidValueError | StackEmptyError
      ACON::Style::Athena.new(input, output).error err.inspect
      ACON::Command::Status::FAILURE
    end

    def fetch_register : Int32
      value = value!
      if REGISTERS.includes?(value)
        (value % MAX_VALUE).to_i32
      else
        raise InvalidValueError.new
      end
    end

    def fetch_value : UInt16
      value = value!
      if value >= INVALID_VALUE
        raise InvalidValueError.new
      elsif REGISTERS.includes?(value)
        @registers[value % MAX_VALUE]
      else
        value
      end
    end

    private def value! : UInt16
      @memory[@pc].tap do
        @pc += 1
      end
    end

    private def op_halt
      raise HaltError.new
    end

    private def op_set
      reg = fetch_register
      value = fetch_value
      @registers[reg] = value
    end

    private def op_push
      @stack << fetch_value
    end

    private def op_pop
      if value = @stack.pop?
        reg = fetch_register
        @registers[reg] = value
      else
        raise StackEmptyError.new
      end
    end

    private def op_eq
      reg = fetch_register
      a = fetch_value
      b = fetch_value
      @registers[reg] = (a == b) ? 1_u16 : 0_u16
    end

    private def op_gt
      reg = fetch_register
      a = fetch_value
      b = fetch_value
      @registers[reg] = (a > b) ? 1_u16 : 0_u16
    end

    private def op_jmp
      @pc = fetch_value.to_i32
    end

    private def op_jt
      a = fetch_value
      b = fetch_value
      if a != 0_u16
        @pc = b.to_i32
      end
    end

    private def op_jf
      a = fetch_value
      b = fetch_value
      if a == 0_u16
        @pc = b.to_i32
      end
    end

    private def op_add
      reg = fetch_register
      a = fetch_value
      b = fetch_value
      @registers[reg] = (a + b) % MAX_VALUE
    end

    private def op_mult
      reg = fetch_register
      a = fetch_value
      b = fetch_value
      value = (a.to_u64 * b.to_u64) % MAX_VALUE.to_u64
      @registers[reg] = value.to_u16
    end

    private def op_mod
      reg = fetch_register
      a = fetch_value
      b = fetch_value
      @registers[reg] = a % b
    end

    private def op_and
      reg = fetch_register
      a = fetch_value
      b = fetch_value
      @registers[reg] = a & b
    end

    private def op_or
      reg = fetch_register
      a = fetch_value
      b = fetch_value
      @registers[reg] = a | b
    end

    private def op_not
      reg = fetch_register
      value = fetch_value
      @registers[reg] = (MAX_VALUE - 1) - value
    end

    private def op_rmem
      reg = fetch_register
      address = fetch_value
      value = @memory[address]
      @registers[reg] = value
    end

    private def op_wmem
      address = fetch_value
      value = fetch_value
      @memory[address] = value
    end

    private def op_call
      a = fetch_value
      next_op = @pc
      @stack << next_op.to_u16
      @pc = a.to_i32
    end

    private def op_ret
      if value = @stack.pop?
        @pc = value.to_i32
      else
        raise HaltError.new
      end
    end

    private def op_out(output)
      value = fetch_value
      output.print value.chr
    end

    private def op_in(output)
      reg = fetch_register

      if char = self.line_buffer.shift?
        self.line_cache += char.to_s

        if char == '\n'
          unless self.reading_buffer?
            output.print self.line_cache
          end
          self.line_cache = ""
          self.reading_buffer = false
        end

        input_char = char
      elsif line = gets(chomp: false)
        if line.starts_with?("$debug")
          raw_registers = REGISTERS.to_a

          reader = Debugger.new
          reader.read_loop do |expression|
            case expression
            when "clear", "clr"
              reader.clear_history
            when "reset", "rst"
              reader.reset
            when "exit", "quit", "q"
              break
            when "registers", "reg"
              @registers.each_with_index do |reg_value, index|
                output.puts "#{raw_registers[index]} [#{index}]: #{reg_value}"
              end
            when "stack", "stk"
              @stack.each_with_index do |value, index|
                output.puts "#{index}: #{value}"
              end
            when "memory", "mem"
              range = (@pc - 5)..(@pc + 5)
              range.each do |pc|
                prefix = pc == @pc ? ">" : ""
                output.puts "#{prefix}[#{pc}]: #{@memory[pc]}"
              end
            when "help", "h"
              output.puts <<-TEXT
              Commands:
                registers, reg   View Registers
                stack, stk       View Stack
                memory, mem      View Memory (+/- 5 addresses)
                clear, clr       Clear history
                reset, rst       Reset
                exit, quit, q    Exit
                help, h          Print this help
              TEXT
            when .presence
              # TODO
            end
          end
        else
          char, *chars = line.chars

          self.line_buffer += Deque(Char).new(chars)
          self.line_cache = char.to_s
          self.reading_buffer = true

          input_char = char
        end
      end

      input_char = '\n' unless input_char

      @registers[reg] = input_char.ord.to_u16
    end

    private def op_noop
    end
  end
end
