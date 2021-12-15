require "./spec_helper"

Spectator.describe SynacorChallenge::VM do
  context "op codes" do
    describe "halt" do
      subject do
        io = IO::Memory.new
        io.write_bytes(0_u16, IO::ByteFormat::LittleEndian)
        io.rewind
      end

      it "should terminate program" do
        expect(described_class.new(subject).main).to eq(-1)
      end
    end

    describe "out" do
      subject do
        io = IO::Memory.new
        io.write_bytes(19_u16, IO::ByteFormat::LittleEndian)
        io.write_bytes(101_u16, IO::ByteFormat::LittleEndian)
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
        [6, 5, 21, 19, 102, 19, 103].each do |n|
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
  end
end
