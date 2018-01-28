unless File.exist?(File.join(File.dirname(__FILE__), "./app.config"))
  puts "Couldn't find app.config! Make sure the file exists."
  return
end

require "drb/drb"
require_relative "lib/profit_trailer"

puts "Connecting to ProfitTrailer Slack bot..."
DRb.start_service
client = DRbObject.new_with_uri("druby://#{ProfitTrailer.config["PT_BOT_BRIDGE_URI"]}")
puts "CONNECTED to ProfitTrailer Slack bot!\n"

puts "Starting ProfitTrailer log tailer...\n"
ProfitTrailer::Logger.run(client: client)
