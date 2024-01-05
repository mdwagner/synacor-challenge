require "athena-console"
require "reply"
require "colorize"
require "./synacor/exceptions"
require "./synacor/op_code"
require "./synacor/vm"
require "./synacor/debugger"
require "./synacor/run_command"

app = ACON::Application.new("synacor-challenge")

app.add Synacor::RunCommand.new

app.default_command("run", true)

app.run
