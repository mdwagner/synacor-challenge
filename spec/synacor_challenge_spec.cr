require "./spec_helper"

Spectator.describe SynacorChallenge::VM do
  alias OpCode = SynacorChallenge::OpCode

  context "op codes" do
    describe "halt" do
      subject do
        io = IO::Memory.new
        [OpCode::Halt].each do |n|
          io.write_bytes(n.to_u16, IO::ByteFormat::LittleEndian)
        end
        io.rewind
      end

      it "should terminate program" do
        expect(described_class.new(subject).main).to eq(-1)
      end
    end

    describe "out" do
      subject do
        io = IO::Memory.new
        [OpCode::Out, 101].each do |n|
          io.write_bytes(n.to_u16, IO::ByteFormat::LittleEndian)
        end
        io.rewind
      end
      let(stdout) { IO::Memory.new }

      it "should write 'e' to stdout" do
        described_class.new(subject, stdout: stdout).main
        expect(stdout.rewind.to_s).to eq("e")
      end
    end

    describe "jmp" do
      subject do
        io = IO::Memory.new
        [OpCode::Jmp, 5, OpCode::Noop, OpCode::Out, 102, OpCode::Out, 103].each do |n|
          io.write_bytes(n.to_u16, IO::ByteFormat::LittleEndian)
        end
        io.rewind
      end
      let(stdout) { IO::Memory.new }

      it "should jump to write 'g' to stdout" do
        described_class.new(subject, stdout: stdout).main
        expect(stdout.rewind.to_s).to eq("g")
      end
    end

    describe "jt" do
      subject do
        io = IO::Memory.new
        [OpCode::Jt, 1, 6, OpCode::Noop, OpCode::Out, 102, OpCode::Out, 104].each do |n|
          io.write_bytes(n.to_u16, IO::ByteFormat::LittleEndian)
        end
        io.rewind
      end
      let(stdout) { IO::Memory.new }

      it "should jump to write 'h' to stdout since 1 is non-zero" do
        described_class.new(subject, stdout: stdout).main
        expect(stdout.rewind.to_s).to eq("h")
      end
    end

    describe "jf" do
      subject do
        io = IO::Memory.new
        [OpCode::Jf, 0, 6, OpCode::Noop, OpCode::Out, 102, OpCode::Out, 105].each do |n|
          io.write_bytes(n.to_u16, IO::ByteFormat::LittleEndian)
        end
        io.rewind
      end
      let(stdout) { IO::Memory.new }

      it "should jump to write 'i' to stdout since 0 is zero" do
        described_class.new(subject, stdout: stdout).main
        expect(stdout.rewind.to_s).to eq("i")
      end
    end

    describe "set" do
      subject do
        io = IO::Memory.new
        register_zero = 2 ** 15
        [OpCode::Set, register_zero, 106, OpCode::Noop, OpCode::Out, register_zero].each do |n|
          io.write_bytes(n.to_u16, IO::ByteFormat::LittleEndian)
        end
        io.rewind
      end
      let(stdout) { IO::Memory.new }

      it "should set register 0 to 'j' value and write 'j' to stdout" do
        described_class.new(subject, stdout: stdout).main
        expect(stdout.rewind.to_s).to eq("j")
      end
    end
  end
end
