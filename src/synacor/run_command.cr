module Synacor
  class RunCommand < ACON::Command
    def configure : Nil
      name("run")
      argument("binary", :optional, "Synacor program challenge.bin")
      option("load", "l", ACON::Input::Option::Value[:optional, :is_array])
      option("debug", "x", :none)
    end

    property! vm : VM

    def setup(input : ACON::Input::Interface, output : ACON::Output::Interface) : Nil
      binary_path = input.argument("binary", String?) || "#{__DIR__}/../../instructions/challenge.bin"
      save_paths = input.option("load", Array(String))

      io = IO::Memory.new
      save_paths.each do |save_path|
        io << File.read(save_path)
      end
      io.rewind

      self.vm = VM.new(io, output)
      self.vm.load(binary_path)
    end

    def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
      if input.option("debug", Bool?)
        Debugger.new(self.vm, output).debugger_loop
      else
        self.vm.main_loop
      end

      ACON::Command::Status::SUCCESS
    rescue err : HaltError | InvalidValueError | StackEmptyError
      ACON::Style::Athena.new(input, output).error err.inspect
      ACON::Command::Status::FAILURE
    end

    #def disassembler(output)
      #File.open("./challenge.asm", mode: "w") do |io|
        #pc = 0
        #while pc < @memory.size
          #raw_value = @memory[pc]
          #pc += 1
          #if opcode = OpCode.from_value?(raw_value)
            #io << sprintf("%5d", pc - 1)
            #io << ": "
            #io << opcode.op_name
            #opcode.op_arg_count.times do
              #arg = @memory[pc]
              #if REGISTERS.includes?(arg)
                #io << " $#{arg % MAX_VALUE}"
              #elsif opcode.out? && (32..126).includes?(arg.to_i)
                #io << " #{arg}   \t# #{arg.chr.inspect}"
              #else
                #io << " #{arg}"
              #end
              #pc += 1
            #end
            #io << '\n'
          #else
            ## Not an instruction, just a memory value
            #io << sprintf("%5d", pc - 1)
            #io << ": #{raw_value}\n"
          #end
        #end
      #end
    #end

    #def print_program(output)
      #raw_registers = REGISTERS.to_a
      #range = (@pc - 4)..(@pc + 4)

      #mem_output = String.build do |str|
        #str << "MEMORY:\n".colorize.yellow
        #str << '['
        #str << ' '
        ## memory address columns
        #range.each_with_index do |addr, index|
          #pc_addr = sprintf("%05d", addr)
          #if addr == @pc
            #str << pc_addr.colorize.red
          #else
            #str << pc_addr.colorize.blue
          #end
          #str << ' ' unless index == range.size - 1
        #end
        #str << ' '
        #str << ']'
        #str << '\n'
        #str << '['
        #str << ' '
        ## memory address values
        #range.each_with_index do |addr, index|
          #str << sprintf("%5d", @memory[addr])
          #str << ' ' unless index == range.size - 1
        #end
        #str << ' '
        #str << ']'
      #end

      #reg_output = String.build do |str|
        #str << "REGISTERS:\n".colorize.yellow
        #str << '['
        #str << ' '
        ## register columns
        #@registers.each_with_index do |_, index|
          #str << sprintf("%05d", raw_registers[index]).colorize.blue
          #str << ' ' unless index == @registers.size - 1
        #end
        #str << ' '
        #str << ']'
        #str << '\n'
        #str << '['
        #str << ' '
        ## register index columns
        #@registers.each_with_index do |_, index|
          #str << sprintf("%5d", index + 1).colorize.blue
          #str << ' ' unless index == @registers.size - 1
        #end
        #str << ' '
        #str << ']'
        #str << '\n'
        #str << '['
        #str << ' '
        ## register values
        #@registers.each_with_index do |reg_value, index|
          #str << sprintf("%5d", reg_value)
          #str << ' ' unless index == @registers.size - 1
        #end
        #str << ' '
        #str << ']'
      #end

      #stk_output = String.build do |str|
        #str << "STACK (BOTTOM -> TOP):\n".colorize.yellow
        #str << '['
        #str << ' '
        ## stack index columns
        #@stack.each_with_index do |value, index|
          #str << sprintf("%5d", index).colorize.blue
          #str << ' ' unless index == @stack.size - 1
        #end
        #str << ' '
        #str << ']'
        #str << '\n'
        #str << '['
        #str << ' '
        ## stack values
        #@stack.each_with_index do |value, index|
          #str << sprintf("%5d", value)
          #str << ' ' unless index == @stack.size - 1
        #end
        #str << ' '
        #str << ']'
      #end

      #output.puts mem_output
      #output.puts ""
      #output.puts reg_output
      #output.puts ""
      #output.puts stk_output
      #output.puts ""
    #end
  end
end
