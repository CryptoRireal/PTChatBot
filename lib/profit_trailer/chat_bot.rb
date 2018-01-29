require "date"
require "slack-ruby-bot"

class ProfitTrailer::ChatBot < SlackRubyBot::Bot
  @@help =
    "*ProfitTrailer ChatBot* - This bot allows you to get basic statistics on the current state of your ProfitTrailer bot.\n\n" +
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
      client.say(channel: data.channel, text: ProfitTrailer::ChatBot.profit_summary)
    when "pairs"
      client.say(channel: data.channel, text: ProfitTrailer::ChatBot.pairs_summary)
    when "dca"
      client.say(channel: data.channel, text: ProfitTrailer::ChatBot.dca_summary)
    when "somon"
      client.say(channel: data.channel, text: ProfitTrailer::ChatBot.set_som("on"))
    when "somoff"
      client.say(channel: data.channel, text: ProfitTrailer::ChatBot.set_som("off"))
    when "stop"
      client.say(channel: data.channel, text: ProfitTrailer::ChatBot.set_stop)
    else
      client.say(channel: data.channel, text: @@help)
    end
  end

  command("help") do |client, data, match|
    client.say(channel: data.channel, text: @@help)
  end

  command("profit") do |client, data, match|
    client.say(channel: data.channel, text: ProfitTrailer::ChatBot.profit_summary)
  end

  command("pairs") do |client, data, match|
    client.say(channel: data.channel, text: ProfitTrailer::ChatBot.pairs_summary)
  end

  command("dca") do |client, data, match|
    client.say(channel: data.channel, text: ProfitTrailer::ChatBot.dca_summary)
  end

  command("som") do |client, data, match|
    client.say(channel: data.channel, text: ProfitTrailer::ChatBot.set_som(match["expression"]))
  end

  class << self
    def profit_summary
      data = ProfitTrailer::API.fetch_data(:profit)

      return data[:error] if data[:error]

      "Current profit for today is *#{data[:profit_today_btc]} #{data[:market]}* (_#{data[:profit_today_pct]}_) on a total value of #{data[:total_value_btc]} (*#{data[:total_value_usd]}*) #{data[:market]}\n" +
      "Yesterday's profit was *#{data[:profit_yesterday_btc]} #{data[:market]}* (_#{data[:profit_yesterday_pct]}_)\n" +
      "Last week's profit was *#{data[:profit_week_btc]} #{data[:market]}* (_#{data[:profit_week_pct]}_)"
    end

    def pairs_summary
      data = ProfitTrailer::API.fetch_data(:pairs)

      return data[:error] if data.is_a?(Hash) && data[:error]
      return "Pairs Log is currently empty" if data.empty?

      data.map.with_index do |pair, index|
        "#{index + 1}. " +
        "*Date*: #{pair[:date]}, " +
        "*Coin*: #{pair[:market]}, " +
        # "*Sell Strat*: #{pair[:sell_strat]}, " +
        "*Current Price*: #{pair[:current_price_btc]}, " +
        "*Bought Price*: #{pair[:average_price_btc]}, " +
        "*Profit*: #{pair[:profit_pct]} (_#{pair[:profit_usd]}_), " +
        "*Volume*: #{pair[:volume]}, " +
        "*Total Amount*: #{pair[:total_amount]}, " +
        "*Estimated Value*: _#{pair[:estimated_value_usd]}_"
      end.
      join("\n")
    end

    def dca_summary
      data = ProfitTrailer::API.fetch_data(:dca)

      return data[:error] if data.is_a?(Hash) && data[:error]
      return "DCA Log is currently empty" if data.empty?

      data.map.with_index do |dca, index|
        "#{index + 1}. " +
        "*Date*: #{dca[:date]}, " +
        "*Coin*: #{dca["market"]}, " +
        "*Current Price*: #{dca[:current_price_btc]}, " +
        "*Bought Price*: #{dca[:average_price_btc]}, " +
        "*DCA*: #{dca["dca_count"]}, " +
        "*Profit*: #{dca[:profit_pct]} (_#{dca[:profit_usd]}_), " +
        "*Volume*: #{dca[:volume]}, " +
        "*Total Amount*: #{dca[:total_amount]}, " +
        "*Current Price*: #{dca[:current_price_btc]}, " +
        "*Average Price*: #{dca[:average_price_btc]}, " +
        "*Estimated Value*: #{dca[:estimated_value_btc]} (_#{dca[:estimated_value_usd]}_)"
      end.
      join("\n")
    end

    def set_som(value)
      response =
        case value.upcase!
        when "ON" then ProfitTrailer::API.set_som(:on)
        when "OFF" then ProfitTrailer::API.set_som(:off)
        else false
        end

      if response
        "Sell Only Mode: *#{value}*"
      else
        "Couldn't update Sell Only Mode. Check your settings."
      end
    end

    def set_stop
      if ProfitTrailer::API.set_stop
        "ProfitTrailer has been *STOPPED*"
      else
        "Couldn't stop ProfitTrailer. Check your settings."
      end
    end
  end
end
