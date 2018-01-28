unless File.exist?(File.join(File.dirname(__FILE__), "./app.config"))
  puts "Couldn't find app.config! Make sure the file exists."
  return
end

require "drb/drb"
require_relative "lib/profit_trailer"

DRb.start_service("druby://#{ProfitTrailer.config["PT_BOT_BRIDGE_URI"]}", ProfitTrailer::Bot.instance.send(:client))

puts "Starting ProfitTrailer Slack bot...\n"
ProfitTrailer::Bot.run
