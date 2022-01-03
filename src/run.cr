require "option_parser"
require "./synacor_challenge"

use_save = false

OptionParser.parse do |parser|
  parser.banner = "Usage: synacor_challenge [arguments]"
  parser.on("-s", "--save", "Load embedded save file") { use_save = true }
  parser.on("-h", "--help", "Show this help") do
    puts parser
    exit
  end
end

save_file = Deque.new <<-INPUT.chars
take tablet
use tablet
doorway
north
north
bridge
continue
down
east
take empty lantern
west
west
passage
ladder
west
south
north
take can
use can
use lantern
west
ladder
darkness
continue
west
west
west
west
north
take red coin
north
west
take blue coin
up
take shiny coin
down
east
east
take concave coin
down
take corroded coin
up
west
INPUT
save_file << '\n'

File.open("#{__DIR__}/../instructions/challenge.bin", mode: "rb") do |f|
  vm = SynacorChallenge::SynacorVM.new(f)
  vm.save_file = save_file if use_save
  vm.main
end
