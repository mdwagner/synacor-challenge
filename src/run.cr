require "./synacor_challenge"

File.open("#{__DIR__}/../instructions/challenge.bin", mode: "rb") do |f|
  SynacorChallenge::VM.new(f).main
end
