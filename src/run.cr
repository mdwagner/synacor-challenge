require "./synacor_challenge"

File.open("#{__DIR__}/../instructions/challenge.bin", mode: "rb") do |f|
  SynacorChallenge::SynacorVM.new(f).main
end
