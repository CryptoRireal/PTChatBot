module ProfitTrailer
end

require "./profit_trailer/api"
require "./profit_trailer/bot"
require "./profit_trailer/logs"

ProfitTrailer::Bot.run
