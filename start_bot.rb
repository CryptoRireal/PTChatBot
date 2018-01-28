require "drb/drb"

require_relative "lib/profit_trailer"

DRb.start_service("druby://#{ProfitTrailer.config["PT_BOT_BRIDGE_URI"]}", ProfitTrailer::Bot.instance.send(:client))

puts "Starting ProfitTrailer Slack bot...\n"
ProfitTrailer::Bot.run
