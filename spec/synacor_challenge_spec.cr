require "./spec_helper"

alias LittleEndian = IO::ByteFormat::LittleEndian
alias SynacorVM = SynacorChallenge::SynacorVM
alias OpCode = SynacorChallenge::OpCode
alias Status = SynacorChallenge::Status
alias StackEmptyException = SynacorChallenge::StackEmptyException

Spectator.describe SynacorVM do
  REGISTERS = SynacorChallenge::REGISTERS

  context "OpCode" do
    let(io) { IO::Memory.new }
    let(stdout) { IO::Memory.new }
    let(stderr) { IO::Memory.new }

    describe "Halt <>" do
      subject { OpCode::Halt }

      it "should terminate program" do
        [subject].each do |n|
          io.write_bytes(n.to_u16, LittleEndian)
        end
        io.rewind

        expect(described_class.new(io).main).to eq(Status::Halt)
      end
    end

    describe "Set <a, b>" do
      subject { OpCode::Set }

      it "should set register <a> to value of <b>" do
        register = REGISTERS.first
        value = 101
        [subject, register, value].each do |n|
          io.write_bytes(n.to_u16, LittleEndian)
        end
        io.rewind

        instance = described_class.new(io)
        instance.main
        reg = instance.get_register(register)
        expect(instance.register[reg]).to eq(value.to_u16)
      end
    end

    describe "Push <a>" do
      subject { OpCode::Push }

      it "should push <a> onto stack" do
        value = 4
        [subject, value].each do |n|
          io.write_bytes(n.to_u16, LittleEndian)
        end
        io.rewind

        instance = described_class.new(io)
        instance.main
        expect(instance.stack.first).to eq(value.to_u16)
      end
    end

    describe "Pop <a>" do
      subject { OpCode::Pop }

      it "should remove top element from stack and write it to <a>" do
        register = REGISTERS.first
        [subject, register].each do |n|
          io.write_bytes(n.to_u16, LittleEndian)
        end
        io.rewind
        top_element = 8_u16

        instance = described_class.new(io)
        instance.stack << top_element
        instance.main
        reg = instance.get_register(register)
        expect(instance.register[reg]).to eq(top_element.to_u16)
        expect(instance.stack.size).to eq(0)
      end

      it "should error when removing top element from empty stack" do
        register = REGISTERS.first
        [subject, register].each do |n|
          io.write_bytes(n.to_u16, LittleEndian)
        end
        io.rewind

        expect(described_class.new(io, stderr: stderr).main).to eq(Status::Error)
        expect(stderr.rewind.to_s).to contain(StackEmptyException.name)
      end
    end

    describe "Eq <a, b, c>" do
      subject { OpCode::Eq }

      it "should set <a> to 1 when <b> == <c>" do
        register = REGISTERS.first
        [subject, register, 4, 4].each do |n|
          io.write_bytes(n.to_u16, LittleEndian)
        end
        io.rewind

        instance = described_class.new(io)
        instance.main
        reg = instance.get_register(register)
        expect(instance.register[reg]).to eq(1_u16)
      end

      it "should set <a> to 0 when <b> != <c>" do
        register = REGISTERS.first
        [subject, register, 4, 5].each do |n|
          io.write_bytes(n.to_u16, LittleEndian)
        end
        io.rewind

        instance = described_class.new(io)
        instance.main
        reg = instance.get_register(register)
        expect(instance.register[reg]).to eq(0_u16)
      end
    end

    describe "Gt <a, b, c>" do
      subject { OpCode::Gt }

      it "should set <a> to 1 when <b> > <c>" do
        register = REGISTERS.first
        [subject, register, 5, 4].each do |n|
          io.write_bytes(n.to_u16, LittleEndian)
        end
        io.rewind

        instance = described_class.new(io)
        instance.main
        reg = instance.get_register(register)
        expect(instance.register[reg]).to eq(1_u16)
      end

      it "should set <a> to 0 when <b> < <c>" do
        register = REGISTERS.first
        [subject, register, 4, 5].each do |n|
          io.write_bytes(n.to_u16, LittleEndian)
        end
        io.rewind

        instance = described_class.new(io)
        instance.main
        reg = instance.get_register(register)
        expect(instance.register[reg]).to eq(0_u16)
      end
    end

    describe "Jmp <a>" do
      subject { OpCode::Jmp }

      it "should jump to <a>", pending: "Needs integration testing" do
      end
    end

    describe "Jt <a, b>" do
      subject { OpCode::Jt }

      it "should jump to <b> when <a> != 0", pending: "Needs integration testing" do
      end
    end

    describe "Jf <a, b>" do
      subject { OpCode::Jf }

      it "should jump to <b> when <a> == 0", pending: "Needs integration testing" do
      end
    end

    describe "Add <a, b, c>" do
      subject { OpCode::Add }

      it "should assign into <a> the sum of <b> and <c>" do
        register = REGISTERS.first
        [subject, register, 4, 8].each do |n|
          io.write_bytes(n.to_u16, LittleEndian)
        end
        io.rewind

        instance = described_class.new(io)
        instance.main
        reg = instance.get_register(register)
        expect(instance.register[reg]).to eq(12_u16)
      end

      it "should assign into <a> the sum of <b> and <c> (modulo 32768)" do
        register = REGISTERS.first
        [subject, register, 12345, 31214].each do |n|
          io.write_bytes(n.to_u16, LittleEndian)
        end
        io.rewind

        instance = described_class.new(io)
        instance.main
        reg = instance.get_register(register)
        expect(instance.register[reg]).to eq(10791_u16)
      end
    end

    describe "Mult <a, b, c>" do
      subject { OpCode::Mult }

      it "should store into <a> the product of <b> and <c>" do
        register = REGISTERS.first
        [subject, register, 5, 5].each do |n|
          io.write_bytes(n.to_u16, LittleEndian)
        end
        io.rewind

        instance = described_class.new(io)
        instance.main
        reg = instance.get_register(register)
        expect(instance.register[reg]).to eq(25_u16)
      end

      it "should store into <a> the product of <b> and <c> (modulo 32768)" do
        register = REGISTERS.first
        [subject, register, 12345, 31214].each do |n|
          io.write_bytes(n.to_u16, LittleEndian)
        end
        io.rewind

        instance = described_class.new(io)
        instance.main
        reg = instance.get_register(register)
        expect(instance.register[reg]).to eq(17918_u16)
      end
    end

    describe "Mod <a, b, c>" do
      subject { OpCode::Mod }

      it "should store into <a> the remainder of <b> divided by <c>" do
        register = REGISTERS.first
        [subject, register, 13, 7].each do |n|
          io.write_bytes(n.to_u16, LittleEndian)
        end
        io.rewind

        instance = described_class.new(io)
        instance.main
        reg = instance.get_register(register)
        expect(instance.register[reg]).to eq(6_u16)
      end
    end

    describe "And <a, b, c>" do
      subject { OpCode::And }

      it "should store into <a> the bitwise and of <b> divided by <c> when <b> == <c>" do
        register = REGISTERS.first
        [subject, register, 2, 2].each do |n|
          io.write_bytes(n.to_u16, LittleEndian)
        end
        io.rewind

        instance = described_class.new(io)
        instance.main
        reg = instance.get_register(register)
        expect(instance.register[reg]).to eq(2_u16)
      end

      it "should store into <a> the bitwise and of <b> divided by <c> when <b> != <c>" do
        register = REGISTERS.first
        [subject, register, 2, 4].each do |n|
          io.write_bytes(n.to_u16, LittleEndian)
        end
        io.rewind

        instance = described_class.new(io)
        instance.main
        reg = instance.get_register(register)
        expect(instance.register[reg]).to eq(0_u16)
      end
    end

    describe "Or <a, b, c>" do
      subject { OpCode::Or }

      it "should store into <a> the bitwise or of <b> divided by <c>" do
        register = REGISTERS.first
        [subject, register, 1, 0].each do |n|
          io.write_bytes(n.to_u16, LittleEndian)
        end
        io.rewind

        instance = described_class.new(io)
        instance.main
        reg = instance.get_register(register)
        expect(instance.register[reg]).to eq(1_u16)
      end
    end

    describe "Not <a, b>" do
      subject { OpCode::Not }

      it "should store into <a> the 15-bit bitwise inverse of <b>", :skip do
      end
    end

    describe "Rmem <a, b>" do
      subject { OpCode::Rmem }

      it "should read memory address <b> and write into <a>", :skip do
      end
    end

    describe "Wmem <a, b>" do
      subject { OpCode::Wmem }

      it "should write value from <b> into memory at address <a>", :skip do
      end
    end

    describe "Call <a>" do
      subject { OpCode::Call }

      it "should write address of next instruction to stack and jump to <a>", :skip do
      end
    end

    describe "Ret <>" do
      subject { OpCode::Ret }

      it "should remove top element from stack and jump to it", :skip do
      end

      it "should halt when removing top element from stack", :skip do
      end
    end

    describe "Out <a>" do
      subject { OpCode::Out }

      it "should write char of ascii code <a> to stdout" do
        char = 'e'
        [subject, char.ord].each do |n|
          io.write_bytes(n.to_u16, LittleEndian)
        end
        io.rewind

        instance = described_class.new(io, stdout: stdout)
        instance.main
        expect(stdout.rewind.to_s).to eq(char.to_s)
      end
    end

    describe "In <a>" do
      subject { OpCode::In }

      it "should read char from stdin and write ascii code to <a>", :skip do
      end
    end

    describe "Noop <>" do
      subject { OpCode::Noop }

      it "should do nothing" do
        [subject].each do |n|
          io.write_bytes(n.to_u16, LittleEndian)
        end
        io.rewind

        expect(described_class.new(io).main).to eq(Status::Ok)
      end
    end
  end
end
