require "date"
require "slack-ruby-bot"

class ProfitTrailer::Bot < SlackRubyBot::Bot
  @@help =
    "*ProfitTrailer Bot* - This bot allows you to get basic statistics on the current state of your ProfitTrailer bot.\n\n" +
    "*Commands:*\n" +
    "*help* - What you're reading now\n" +
    "*profit* - Tells you today's, yesterday's, and this week's profit numbers\n" +
    "*pairs* - Provides a summary of any active pairs\n" +
    "*dca* - Provides a summary of any pairs currently in DCA\n" +
    "*som* - Sets the Sell Only Mode Override setting. Accepts \"on\" and \"off\" values\n" +
    "*stop* - Stops ProfitTrailer. Note that turning off ProfitTrailer will prevent this bot from working until it is restarted!"

  operator("!") do |client, data, match|
    case(match["expression"])
    when "profit"
      client.say(channel: data.channel, text: ProfitTrailer::Bot.profit_summary)
    # when "pairs"
    #   client.say(channel: data.channel, text: ProfitTrailer.pairs_summary)
    # when "dca"
    #   client.say(channel: data.channel, text: ProfitTrailer.dca_summary)
    # when "somon"
    #   client.say(channel: data.channel, text: ProfitTrailer.set_som("on"))
    # when "somoff"
    #   client.say(channel: data.channel, text: ProfitTrailer.set_som("off"))
    # when "stop"
    #   client.say(channel: data.channel, text: ProfitTrailer.set_stop)
    else
      client.say(channel: data.channel, text: @@help)
    end
  end

  command("help") do |client, data, match|
    client.say(channel: data.channel, text: @@help)
  end

  command("profit") do |client, data, match|
    client.say(channel: data.channel, text: ProfitTrailer::Bot.profit_summary)
  end

  # command("pairs") do |client, data, match|
  #   client.say(channel: data.channel, text: ProfitTrailer.pairs_summary)
  # end

  # command("dca") do |client, data, match|
  #   client.say(channel: data.channel, text: ProfitTrailer.dca_summary)
  # end

  # command("som") do |client, data, match|
  #   client.say(channel: data.channel, text: ProfitTrailer.set_som(match["expression"]))
  # end

  # command("stop") do |client, data, match|
  #   client.say(channel: data.channel, text: ProfitTrailer.set_stop)
  # end

  class << self
    def profit_summary
      data = ProfitTrailer::API.fetch_data(:profit)

      return data[:error] if data[:error]

      "Current profit for today is *#{data[:profit_today]} #{data[:market]}* (_#{data[:profit_today_pct]}_) on a total value of #{data[:total_value_btc]} (*#{data[:total_value_usd]}*) #{data[:market]}\n" +
      "Yesterday's profit was *#{data[:profit_yesterday]} #{data[:market]}* (_#{data[:profit_yesterday_pct]}_)\n" +
      "Last week's profit was *#{data[:profit_week]} #{data[:market]}* (_#{data[:profit_week_pct]}_)"
    end

    # def pairs_summary
    #   fetch_data

    #   return data[:error] if fetch_error?

    #   pairs.inject([]) do |messages, pair|
    #     average_calc = pair["averageCalculator"]
    #     average_price = average_calc["avgPrice"]
    #     current_price = pair["currentPrice"]
    #     first_bought = average_calc["firstBoughtDate"]
    #     date = Date.parse(first_bought["date"].values.join("-")).to_s
    #     total_amount = average_calc["totalAmount"]
    #     estimated_value = total_amount * current_price
    #     market = pair["market"]
    #     profit = pair["profit"]
    #     sell_strat = pair["sellStrategy"]
    #     volume = pair["volume"]


    #     messages << "*Date*: #{date}, " +
    #                 "*Coin*: #{market}, " +
    #                 "*Sell Strat*: #{sell_strat}, " + 
    #                 "*Current Price*: #{to_btc(current_price)}, " + 
    #                 "*Bought Price*: #{to_btc(average_price)}, " + 
    #                 "*Profit*: #{to_percent(profit)}% (_#{number_to_currency(btc_to_usd(estimated_value * profit * 0.01))}_), " +
    #                 "*Volume*: #{volume.round}, " + 
    #                 "*Estimated Value*: #{to_btc(estimated_value)} (_#{number_to_currency(btc_to_usd(estimated_value))}_)"
    #   end.
    #   join("\n")
    # end

    # def dca_summary
    #   fetch_data

    #   return data[:error] if fetch_error?

    #   dcas.inject([]) do |messages, dca|
    #     profit = dca["profit"]
    #     current_price = dca["currentPrice"]
    #     average_price = dca["averageCalculator"]["avgPrice"]
    #     total_amount = dca["averageCalculator"]["totalAmount"]
    #     estimated_value = total_amount * current_price

    #     messages << "*Pair*: #{dca["market"]}, " +
    #                 "*DCA*: #{dca["boughtTimes"]}, " +
    #                 "*Profit*: #{to_percent(profit)}% (_#{number_to_currency(btc_to_usd(estimated_value * profit * 0.01))}_), " +
    #                 "*Current Price*: #{to_btc(current_price)} #{market} (_#{number_to_currency(btc_to_usd(current_price))}_), " +
    #                 "*Average Price*: #{to_btc(average_price)} #{market} (_#{number_to_currency(btc_to_usd(average_price))}_), " +
    #                 "*Estimated Value*: #{to_btc(estimated_value)} #{market} (_#{number_to_currency(btc_to_usd(estimated_value))}_)"
    #   end.
    #   join("\n")
    # end

    # def set_som(value)
    #   response =
    #     case value.upcase!
    #     when "ON" then som_on
    #     when "OFF" then som_off
    #     else false
    #     end

    #   if response
    #     "Sell Only Mode: *#{value}*"
    #   else
    #     "Couldn't update Sell Only Mode. Check your settings."
    #   end
    # end

    # def set_stop
    #   if stop_pt
    #     "ProfitTrailer has been *STOPPED*"
    #   else
    #     "Couldn't stop ProfitTrailer. Check your settings."
    #   end
    # end
  end
end
