require "./spec_helper"

Spectator.describe SynacorChallenge::VM do
  alias LittleEndian = IO::ByteFormat::LittleEndian
  alias OpCode = SynacorChallenge::OpCode
  alias VMStatus = SynacorChallenge::VMStatus

  MAX_VALUE = SynacorChallenge::VM::MAX_VALUE

  context "op codes" do
    let(stdout) { IO::Memory.new }

    describe "halt" do
      subject do
        io = IO::Memory.new
        [OpCode::Halt].each do |n|
          io.write_bytes(n.to_u16, LittleEndian)
        end
        io.rewind
      end

      it "should terminate program" do
        expect(described_class.new(subject).main).to eq(VMStatus::Halt)
      end
    end

    describe "out" do
      subject do
        io = IO::Memory.new
        [OpCode::Out, 'e'.ord].each do |n|
          io.write_bytes(n.to_u16, LittleEndian)
        end
        io.rewind
      end

      it "should write 'e' to stdout" do
        described_class.new(subject, stdout: stdout).main
        expect(stdout.rewind.to_s).to eq("e")
      end
    end

    describe "jmp" do
      subject do
        io = IO::Memory.new
        [OpCode::Jmp, 5, OpCode::Noop, OpCode::Out, 'f'.ord, OpCode::Out, 'g'.ord].each do |n|
          io.write_bytes(n.to_u16, LittleEndian)
        end
        io.rewind
      end

      it "should jump to write 'g' to stdout" do
        described_class.new(subject, stdout: stdout).main
        expect(stdout.rewind.to_s).to eq("g")
      end
    end

    describe "jt" do
      subject do
        io = IO::Memory.new
        [OpCode::Jt, 1, 6, OpCode::Noop, OpCode::Out, 'f'.ord, OpCode::Out, 'h'.ord].each do |n|
          io.write_bytes(n.to_u16, LittleEndian)
        end
        io.rewind
      end

      it "should jump to write 'h' to stdout since 1 is non-zero" do
        described_class.new(subject, stdout: stdout).main
        expect(stdout.rewind.to_s).to eq("h")
      end
    end

    describe "jf" do
      subject do
        io = IO::Memory.new
        [OpCode::Jf, 0, 6, OpCode::Noop, OpCode::Out, 'f'.ord, OpCode::Out, 'i'.ord].each do |n|
          io.write_bytes(n.to_u16, LittleEndian)
        end
        io.rewind
      end

      it "should jump to write 'i' to stdout since 0 is zero" do
        described_class.new(subject, stdout: stdout).main
        expect(stdout.rewind.to_s).to eq("i")
      end
    end

    describe "set" do
      subject do
        io = IO::Memory.new
        register_zero = MAX_VALUE
        [OpCode::Set, register_zero, 'j'.ord, OpCode::Noop, OpCode::Out, register_zero].each do |n|
          io.write_bytes(n.to_u16, LittleEndian)
        end
        io.rewind
      end

      it "should set register 0 to 'j' value and write 'j' to stdout" do
        described_class.new(subject, stdout: stdout).main
        expect(stdout.rewind.to_s).to eq("j")
      end
    end
  end
end
