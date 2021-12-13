require "./spec_helper"

Spectator.describe SynacorChallenge::VM do
  subject do
    io = IO::Memory.new
    [9, 32768, 32769, 4, 19, 32768].each do |n|
      io.write_bytes(n.to_u16, IO::ByteFormat::LittleEndian)
    end
    io.rewind
  end

  it "works" do
    SynacorChallenge::VM.new(subject).main
  end
end
