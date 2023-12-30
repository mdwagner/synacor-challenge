require "colorize"

module Synacor
  class Debugger < Reply::Reader
    def prompt(io : IO, line_number : Int32, color? : Bool) : Nil
      io << "debug".colorize.red.toggle(color?)
      io << ':'
      io << sprintf("%03d", line_number)
      io << "> "
    end
  end
end
