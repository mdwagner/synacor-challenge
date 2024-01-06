module Synacor
  private class CustomReader < Reply::Reader
    def prompt(io : IO, line_number : Int32, color? : Bool) : Nil
      io << "debug".colorize.red.toggle(color?)
      io << ':'
      io << sprintf("%03d", line_number)
      io << "> "
    end
  end

  class Debugger
    REGISTERS = VM::REGISTERS.to_a
    MAX_VALUE = VM::MAX_VALUE

    property vm : VM

    property output : ACON::Output::Interface

    property breakpoints = [] of Int32

    property vm_output_io = IO::Memory.new

    def initialize(@vm, @output)
      @vm.output = ACON::Output::IO.new(@vm_output_io)
    end

    def debugger_loop
      reader = CustomReader.new
      reader.read_loop do |expr|
        case expr
        when "exit", "quit", "q"
          break
        when "asm"
          print_disassemble
        when "s", "stepi"
          stepi
        when "n", "nexti"
          nexti
        when "o", "stepo"
          stepo
        when "io"
          print_vm_input
        when "p", "print"
          print_vm_output
        when "clear"
          clear_vm_output
        when "c", "continue"
          continue_until_breakpoint
        when "b"
          print_breakpoints
        when "reg"
          print_registers
        when "stk"
          print_stack
        when "$coin"
          print_solved_coin_problem
        else
          if md = expr.match(/i!(\d+)\s*(.*)/)
            # i!<op> <...>
            interpret_instruction(md)
          elsif md = expr.match(/b!(\d+)/)
            # b!<breakpoint>
            set_breakpoint(md[1].to_i)
          elsif md = expr.match(/bd!(\d+)/)
            # bd!<breakpoint>
            remove_breakpoint(md[1].to_i)
          elsif md = expr.match(/asm!(\d+)/)
            # asm!<pc>
            print_disassemble(md[1].to_i)
          elsif md = expr.match(/io!(.*)/)
            # io!<...>\n
            add_vm_input(md[1])
          end
        end
      end
    end

    def solve_coin_problem : Array(String)
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
      end.not_nil!
    end

    def print_solved_coin_problem
      solve_coin_problem.each do |coin|
        self.output.puts("use #{coin} coin")
      end
    end

    def print_vm_input
      self.output.puts(self.vm.input.to_s)
    end

    def print_vm_output
      self.output.puts(vm_output_io.to_s)
    end

    def add_vm_input(input_str)
      pos = self.vm.input.pos
      self.vm.input.pos = self.vm.input.size
      self.vm.input << input_str
      self.vm.input << '\n'
      self.vm.input.pos = pos
    end

    def print_registers
      String.build do |str|
        str << '['
        str << ' '
        # register columns
        self.vm.registers.each_with_index do |_, index|
          str << sprintf("%05d", REGISTERS[index]).colorize.blue
          str << ' ' unless index == self.vm.registers.size - 1
        end
        str << ' '
        str << ']'
        str << '\n'
        str << '['
        str << ' '
        # register index columns
        self.vm.registers.each_with_index do |_, index|
          str << sprintf("%5d", index).colorize.blue
          str << ' ' unless index == self.vm.registers.size - 1
        end
        str << ' '
        str << ']'
        str << '\n'
        str << '['
        str << ' '
        # register values
        self.vm.registers.each_with_index do |reg_value, index|
          str << sprintf("%5d", reg_value)
          str << ' ' unless index == self.vm.registers.size - 1
        end
        str << ' '
        str << ']'
      end.tap do |str|
        self.output.puts(str)
        self.output.puts ""
      end
    end

    def print_stack
      String.build do |str|
        str << '['
        str << ' '
        # stack index columns
        self.vm.stack.each_with_index do |value, index|
          str << sprintf("%5d", index).colorize.blue
          str << ' ' unless index == self.vm.stack.size - 1
        end
        str << ' '
        str << ']'
        str << '\n'
        str << '['
        str << ' '
        # stack values
        self.vm.stack.each_with_index do |value, index|
          str << sprintf("%5d", value)
          str << ' ' unless index == self.vm.stack.size - 1
        end
        str << ' '
        str << ']'
      end.tap do |str|
        self.output.puts(str)
        self.output.puts ""
      end
    end

    def print_breakpoints
      if self.breakpoints.empty?
        self.output.puts("No breakpoints set")
      else
        self.breakpoints.each do |value|
          self.output.puts(value.to_s)
        end
      end
    end

    def set_breakpoint(breakpoint)
      self.breakpoints << breakpoint
    end

    def remove_breakpoint(breakpoint)
      self.breakpoints.delete(breakpoint)
    end

    def print_disassemble(pc : Int32? = self.vm.pc)
      raw_value = self.vm.memory[pc]
      pc += 1
      if opcode = OpCode.from_value?(raw_value)
        self.output.print sprintf("%5d", pc - 1)
        self.output.print ": "
        self.output.print opcode.op_name
        opcode.op_arg_count.times do
          arg = self.vm.memory[pc]
          if REGISTERS.includes?(arg)
            self.output.print " $#{arg % MAX_VALUE}"
          elsif opcode.out? && (32..126).includes?(arg.to_i)
            self.output.print " #{arg}   \t# #{arg.chr.inspect}"
          else
            self.output.print " #{arg}"
          end
          pc += 1
        end
        self.output.print "\n"
      else
        # Not an instruction, just a memory value
        self.output.print sprintf("%5d", pc - 1)
        self.output.print ": #{raw_value}\n"
      end
    end

    def clear_vm_output
      self.vm_output_io.clear
    end

    def interpret_instruction(md)
      if opcode = OpCode.from_value?(md[1].to_u16)
        args = md[2].split(" ")
        execute_instruction(opcode, args)
      end
    end

    def execute_instruction(opcode, args)
      case opcode
      in .halt?
        self.vm.op_halt
      in .set?
        arg1 = self.vm.to_register(args[0].to_u16)
        arg2 = self.vm.to_value(args[1].to_u16)
        self.vm.op_set(arg1, arg2) { }
      in .push?
        arg1 = self.vm.to_value(args[0].to_u16)
        self.vm.op_push(arg1) { }
      in .pop?
        arg1 = self.vm.to_register(args[0].to_u16)
        self.vm.op_pop(arg1) { }
      in .eq?
        arg1 = self.vm.to_register(args[0].to_u16)
        arg2 = self.vm.to_value(args[1].to_u16)
        arg3 = self.vm.to_value(args[2].to_u16)
        self.vm.op_eq(arg1, arg2, arg3) { }
      in .gt?
        arg1 = self.vm.to_register(args[0].to_u16)
        arg2 = self.vm.to_value(args[1].to_u16)
        arg3 = self.vm.to_value(args[2].to_u16)
        self.vm.op_gt(arg1, arg2, arg3) { }
      in .jmp?
        arg1 = self.vm.to_value(args[0].to_u16)
        self.vm.op_jmp(arg1)
      in .jt?
        arg1 = self.vm.to_value(args[0].to_u16)
        arg2 = self.vm.to_value(args[1].to_u16)
        self.vm.op_jt(arg1, arg2) { }
      in .jf?
        arg1 = self.vm.to_value(args[0].to_u16)
        arg2 = self.vm.to_value(args[1].to_u16)
        self.vm.op_jf(arg1, arg2) { }
      in .add?
        arg1 = self.vm.to_register(args[0].to_u16)
        arg2 = self.vm.to_value(args[1].to_u16)
        arg3 = self.vm.to_value(args[2].to_u16)
        self.vm.op_add(arg1, arg2, arg3) { }
      in .mult?
        arg1 = self.vm.to_register(args[0].to_u16)
        arg2 = self.vm.to_value(args[1].to_u16)
        arg3 = self.vm.to_value(args[2].to_u16)
        self.vm.op_mult(arg1, arg2, arg3) { }
      in .mod?
        arg1 = self.vm.to_register(args[0].to_u16)
        arg2 = self.vm.to_value(args[1].to_u16)
        arg3 = self.vm.to_value(args[2].to_u16)
        self.vm.op_mod(arg1, arg2, arg3) { }
      in .and?
        arg1 = self.vm.to_register(args[0].to_u16)
        arg2 = self.vm.to_value(args[1].to_u16)
        arg3 = self.vm.to_value(args[2].to_u16)
        self.vm.op_and(arg1, arg2, arg3) { }
      in .or?
        arg1 = self.vm.to_register(args[0].to_u16)
        arg2 = self.vm.to_value(args[1].to_u16)
        arg3 = self.vm.to_value(args[2].to_u16)
        self.vm.op_or(arg1, arg2, arg3) { }
      in .not?
        arg1 = self.vm.to_register(args[0].to_u16)
        arg2 = self.vm.to_value(args[1].to_u16)
        self.vm.op_not(arg1, arg2) { }
      in .rmem?
        arg1 = self.vm.to_register(args[0].to_u16)
        arg2 = self.vm.to_value(args[1].to_u16)
        self.vm.op_rmem(arg1, arg2) { }
      in .wmem?
        arg1 = self.vm.to_value(args[0].to_u16)
        arg2 = self.vm.to_value(args[1].to_u16)
        self.vm.op_wmem(arg1, arg2) { }
      in .call?
        arg1 = self.vm.to_value(args[0].to_u16)
        self.vm.op_call(arg1)
      in .ret?
        self.vm.op_ret
      in .out?
        arg1 = self.vm.to_value(args[0].to_u16)
        self.vm.op_out(arg1) { }
      in .in?
        reg = self.vm.to_register(args[0].to_u16)
        if buffered_char = self.vm.input.read_char
          self.vm.output.print(buffered_char)
          self.vm.registers[reg] = buffered_char.ord.to_u16
        else
          self.vm.registers[reg] = '\n'.ord.to_u16
        end
      in .noop?
        self.vm.op_noop { }
      end
    end

    def stepi
      custom_main_loop { false }
    end

    def nexti
      if opcode = OpCode.from_value?(self.vm.memory[self.vm.pc])
        if opcode.call?
          breakpoint = self.vm.pc + 2
          self.breakpoints << breakpoint
          self.continue_until_breakpoint
          self.breakpoints.delete(breakpoint)
        else
          stepi
        end
      else
        stepi
      end
    end

    def stepo
      if OpCode.from_value?(self.vm.memory[self.vm.pc]).try { |op| op.ret? }
        stepi
      else
        continue_until_ret
        stepi
      end
    end

    def continue_until_breakpoint
      custom_main_loop { !self.breakpoints.includes?(self.vm.pc) }
    end

    def continue_until_ret
      custom_main_loop do
        if opcode = OpCode.from_value?(self.vm.memory[self.vm.pc])
          !opcode.ret?
        else
          true
        end
      end
    end

    def custom_main_loop(&block : -> Bool)
      while self.vm.pc < self.vm.memory.size
        if opcode = OpCode.from_value?(self.vm.memory[self.vm.pc])
          case opcode
          in .halt?
            self.vm.op_halt
          in .set?
            self.vm.op_set(self.vm.register_at(1), self.vm.value_at(2)) do
              self.vm.pc += 3
            end
          in .push?
            self.vm.op_push(self.vm.value_at(1)) do
              self.vm.pc += 2
            end
          in .pop?
            self.vm.op_pop(self.vm.register_at(1)) do
              self.vm.pc += 2
            end
          in .eq?
            self.vm.op_eq(self.vm.register_at(1), self.vm.value_at(2), self.vm.value_at(3)) do
              self.vm.pc += 4
            end
          in .gt?
            self.vm.op_gt(self.vm.register_at(1), self.vm.value_at(2), self.vm.value_at(3)) do
              self.vm.pc += 4
            end
          in .jmp?
            self.vm.op_jmp(self.vm.value_at(1))
          in .jt?
            self.vm.op_jt(self.vm.value_at(1), self.vm.value_at(2)) do
              self.vm.pc += 3
            end
          in .jf?
            self.vm.op_jf(self.vm.value_at(1), self.vm.value_at(2)) do
              self.vm.pc += 3
            end
          in .add?
            self.vm.op_add(self.vm.register_at(1), self.vm.value_at(2), self.vm.value_at(3)) do
              self.vm.pc += 4
            end
          in .mult?
            self.vm.op_mult(self.vm.register_at(1), self.vm.value_at(2), self.vm.value_at(3)) do
              self.vm.pc += 4
            end
          in .mod?
            self.vm.op_mod(self.vm.register_at(1), self.vm.value_at(2), self.vm.value_at(3)) do
              self.vm.pc += 4
            end
          in .and?
            self.vm.op_and(self.vm.register_at(1), self.vm.value_at(2), self.vm.value_at(3)) do
              self.vm.pc += 4
            end
          in .or?
            self.vm.op_or(self.vm.register_at(1), self.vm.value_at(2), self.vm.value_at(3)) do
              self.vm.pc += 4
            end
          in .not?
            self.vm.op_not(self.vm.register_at(1), self.vm.value_at(2)) do
              self.vm.pc += 3
            end
          in .rmem?
            self.vm.op_rmem(self.vm.register_at(1), self.vm.value_at(2)) do
              self.vm.pc += 3
            end
          in .wmem?
            self.vm.op_wmem(self.vm.value_at(1), self.vm.value_at(2)) do
              self.vm.pc += 3
            end
          in .call?
            self.vm.op_call(self.vm.value_at(1))
          in .ret?
            self.vm.op_ret
          in .out?
            self.vm.op_out(self.vm.value_at(1)) do
              self.vm.pc += 2
            end
          in .in?
            reg = self.vm.register_at(1)
            if buffered_char = self.vm.input.read_char
              self.vm.output.print(buffered_char)
              self.vm.registers[reg] = buffered_char.ord.to_u16
            else
              self.vm.registers[reg] = '\n'.ord.to_u16
            end
            self.vm.pc += 2
          in .noop?
            self.vm.op_noop do
              self.vm.pc += 1
            end
          end
        else
          self.vm.pc += 1
        end
        break unless block.call
      end
    end
  end
end
