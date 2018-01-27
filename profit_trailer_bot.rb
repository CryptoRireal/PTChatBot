require "action_view"
require "date"
require "faraday"
require "faraday-cookie_jar"
require "json"
require "slack-ruby-bot"

class ProfitTrailerBot < SlackRubyBot::Bot
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
      client.say(channel: data.channel, text: ProfitTrailer.profit_summary)
    when "pairs"
      client.say(channel: data.channel, text: ProfitTrailer.pairs_summary)
    when "dca"
      client.say(channel: data.channel, text: ProfitTrailer.dca_summary)
    when "somon"
      client.say(channel: data.channel, text: ProfitTrailer.set_som("on"))
    when "somoff"
      client.say(channel: data.channel, text: ProfitTrailer.set_som("off"))
    when "stop"
      client.say(channel: data.channel, text: ProfitTrailer.set_stop)
    else
      client.say(channel: data.channel, text: @@help)
    end
  end

  command("help") do |client, data, match|
    client.say(channel: data.channel, text: @@help)
  end

  command("profit") do |client, data, match|
    client.say(channel: data.channel, text: ProfitTrailer.profit_summary)
  end

  command("pairs") do |client, data, match|
    client.say(channel: data.channel, text: ProfitTrailer.pairs_summary)
  end

  command("dca") do |client, data, match|
    client.say(channel: data.channel, text: ProfitTrailer.dca_summary)
  end

  command("som") do |client, data, match|
    client.say(channel: data.channel, text: ProfitTrailer.set_som(match["expression"]))
  end

  command("stop") do |client, data, match|
    client.say(channel: data.channel, text: ProfitTrailer.set_stop)
  end
end

class ProfitTrailer
  class << self
    include ActionView::Helpers::NumberHelper

    def profit_summary
      fetch_data

      return data[:error] if fetch_error?

      "Current profit for today is *#{profit_today} #{market}* (_#{profit_today_pct}%_) on a total value of #{total_value} #{market}\n" +
      "Yesterday's profit was *#{profit_yesterday} #{market}* (_#{profit_yesterday_pct}%_)\n" +
      "Last week's profit was *#{profit_week} #{market}* (_#{profit_week_pct}%_)"
    end

    def pairs_summary
      fetch_data

      return data[:error] if fetch_error?

      pairs.inject([]) do |messages, pair|
        average_calc = pair["averageCalculator"]
        average_price = average_calc["avgPrice"]
        current_price = pair["currentPrice"]
        first_bought = average_calc["firstBoughtDate"]
        date = Date.parse(first_bought["date"].values.join("-")).to_s
        total_amount = average_calc["totalAmount"]
        estimated_value = total_amount * current_price
        market = pair["market"]
        profit = pair["profit"]
        sell_strat = pair["sellStrategy"]
        volume = pair["volume"]


        messages << "*Date*: #{date}, " +
                    "*Coin*: #{market}, " +
                    "*Sell Strat*: #{sell_strat}, " + 
                    "*Current Price*: #{to_btc(current_price)}, " + 
                    "*Bought Price*: #{to_btc(average_price)}, " + 
                    "*Profit*: #{to_percent(profit)}% (_#{number_to_currency(btc_to_usd(estimated_value * profit * 0.01))}_), " +
                    "*Volume*: #{volume.round}, " + 
                    "*Estimated Value*: #{to_btc(estimated_value)} (_#{number_to_currency(btc_to_usd(estimated_value))}_)"
      end.
      join("\n")
    end

    def dca_summary
      fetch_data

      return data[:error] if fetch_error?

      dcas.inject([]) do |messages, dca|
        profit = dca["profit"]
        current_price = dca["currentPrice"]
        average_price = dca["averageCalculator"]["avgPrice"]
        total_amount = dca["averageCalculator"]["totalAmount"]
        estimated_value = total_amount * current_price

        messages << "*Pair*: #{dca["market"]}, " +
                    "*DCA*: #{dca["boughtTimes"]}, " +
                    "*Profit*: #{to_percent(profit)}% (_#{number_to_currency(btc_to_usd(estimated_value * profit * 0.01))}_), " +
                    "*Current Price*: #{to_btc(current_price)} #{market} (_#{number_to_currency(btc_to_usd(current_price))}_), " +
                    "*Average Price*: #{to_btc(average_price)} #{market} (_#{number_to_currency(btc_to_usd(average_price))}_), " +
                    "*Estimated Value*: #{to_btc(estimated_value)} #{market} (_#{number_to_currency(btc_to_usd(estimated_value))}_)"
      end.
      join("\n")
    end

    def set_som(value)
      response =
        case value.upcase!
        when "ON" then som_on
        when "OFF" then som_off
        else false
        end

      if response
        "Sell Only Mode: *#{value}*"
      else
        "Couldn't update Sell Only Mode. Check your settings."
      end
    end

    def set_stop
      if stop_pt
        "ProfitTrailer has been *STOPPED*"
      else
        "Couldn't stop ProfitTrailer. Check your settings."
      end
    end

    protected

    def market
      data["market"]
    end

    def balance
      ("%.20f" % data["balance"]).to_f
    end

    def pairs_value
      ("%.20f" % data["totalPairsCurrentValue"]).to_f
    end

    def dca_value
      ("%.20f" % data["totalDCACurrentValue"]).to_f
    end

    def total_value
      (balance + pairs_value + dca_value).round(10)
    end

    def profit_today
      ("%.20f" % data["totalProfitToday"]).to_f.round(10)
    end

    def profit_yesterday
      ("%.20f" % data["totalProfitYesterday"]).to_f.round(10)
    end

    def profit_week
      ("%.20f" % data["totalProfitWeek"]).to_f.round(10)
    end

    def profit_today_pct
      (profit_today / total_value * 100.0).round(2)
    end

    def profit_yesterday_pct
      (profit_yesterday / total_value * 100.0).round(2)
    end

    def profit_week_pct
      (profit_week / total_value * 100.0).round(2)
    end

    def error_message
      @_error_message ||= "There was a problem talking to ProfitTrailer. Check your settings and make sure ProfitTrailer is running."
    end

    def pairs
      @_pairs ||= begin
        keys = [
          "market",
          "profit",
          "averageCalculator",
          "currentPrice",
          "sellStrategy",
          "volume",
          "triggerValue",
        ]

        (data["gainLogData"] || []).map do |pair|
          pair.select { |key, _value| keys.include?(key) }
        end
      end
    end

    def dcas
      @_dcas ||=
        begin
          keys = [
            "BBLow",
            "BBTrigger",
            "boughtTimes",
            "buyProfit",
            "market",
            "profit",
            "averageCalculator",
            "currentPrice",
            "volume",
            "triggerValue",
          ]

          (data["dcaLogData"] || []).map do |dca|
            dca.select { |key, _value| keys.include?(key) }
          end
        end
    end

    private

    def fetch_data
      @_data = nil
      @_pairs = nil
      @_dcas = nil
    end

    def fetch_error?
      data.keys.include?(:error)
    end

    def data
      @_data ||= begin
        response = conn.get("/monitoring/data.json")
        json = JSON.parse(response.body)

        keys = [
          "gainLogData",
          "dcaLogData",
          "balance",
          "totalPairsCurrentValue",
          "totalPairsRealCost",
          "totalDCACurrentValue",
          "totalDCARealCost",
          "totalPendingCurrentValue",
          "totalPendingTargetPrice",
          "totalProfitYesterday",
          "totalProfitToday",
          "totalProfitWeek",
          "version",
          "market",
          "exchange",
          "BTCUSDTPrice",
        ]

        json.select { |key, _value| keys.include?(key) }
      rescue
        { error: error_message }
      end
    end

    def som_on
      begin
        response = conn.get("/settings/overrideSellOnlyMode?enabled=false")
        response.status == 302
      rescue
        { error: error_message }
      end
    end

    def som_off
      begin
        response = conn.get("/settings/overrideSellOnlyMode")
        response.status == 302
      rescue
        { error: error_message }
      end
    end

    def stop_pt
      begin
        response = conn.get("/stop")
        response.status == 200
      rescue
        { error: error_message }
      end
    end

    def conn
      @_conn ||= begin
        Faraday.new(url: ENV["PROFIT_TRAILER_URL"]) do |faraday|
          faraday.use :cookie_jar
          faraday.adapter Faraday.default_adapter
        end.
        tap do |c|
          c.post("/login?password=#{ENV["PROFIT_TRAILER_PASSWORD"]}")
        end
      end
    end

    ### Helpers

    def to_percent(value)
      ("%.2f" % value).to_f
    end

    def to_btc(value)
      ("%.20f" % value).to_f.round(10)
    end

    def btc_to_usd(value)
      data["BTCUSDTPrice"] * value
    end
  end
end

ProfitTrailerBot.run
