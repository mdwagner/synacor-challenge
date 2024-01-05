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

    property vm : VM

    property output : ACON::Output::Interface

    def initialize(@vm, @output)
    end

    def debugger_loop
      reader = CustomReader.new
      reader.read_loop do |expression|
        case expression
        when "clear"
          reader.clear_history
        when "reset"
          reader.reset
        when "exit"
          break
        when "$coin"
          solve_coin_problem.each do |coin|
            self.output.puts "use #{coin} coin"
          end
        when "pc"
          self.output.puts self.vm.pc.to_s
        when .starts_with?("pc+")
          _, *args = expression.split("pc+")
          if arg = args[0]?
            self.vm.pc += arg.to_i
            self.output.puts "pc = #{self.vm.pc}"
          end
        when .starts_with?("pc=")
          _, *args = expression.split("pc=")
          if arg = args[0]?
            self.vm.pc = arg.to_i
            self.output.puts "pc = #{self.vm.pc}"
          end
        when .starts_with?("$r")
          _, *args = expression.split("$r")
          if raw_args = args[0]?
            raw_register, raw_value = raw_args.split("=")
            reg = raw_register.to_i - 1
            value = self.vm.to_value(raw_value.to_u16)
            self.vm.registers[reg] = value
            self.output.puts "$r#{raw_register} = #{value}"
          end
        #when .starts_with?("s+")
        #when .starts_with?("s-")
        #when "p"
        #when .starts_with?("p+")
        #when .starts_with?("p-")
        #when "redir-file"
          #file = File.open("./output.txt", mode: "a")
          #files_open << file
          #output = ACON::Output::IO.new(file)
        #when "redir-file!"
          #file = File.open("./output.txt", mode: "w")
          #files_open << file
          #output = ACON::Output::IO.new(file)
        #when "redir-null"
          #output = ACON::Output::Null.new
        #when "redir-reset"
          #output = output_copy
        #when "n"
        #when "watch"
          #puts "Not implemented: watch"
        #when "memd"
        #when "stdk"
        when "reg"
          reg_output
        #when "stk"
        #when "dump"
        #when .starts_with?("i=")
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

    def reg_output
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
          str << sprintf("%5d", index + 1).colorize.blue
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
  end
end
