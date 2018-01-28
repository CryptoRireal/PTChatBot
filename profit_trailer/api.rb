require "action_view"
require 'active_support/core_ext/hash/indifferent_access'
require "faraday"
require "faraday-cookie_jar"
require "json"

class ProfitTrailer::API
  class << self
    include ActionView::Helpers::NumberHelper

    def fetch_data(command)
      case command
      when :profit then fetch_data_profit
      when :pairs then fetch_data_pairs
      when :dca then fetch_data_dca
      else
        { error: "Received an invalid fetch command" }
      end
    end

    def fetch_data_profit
      data = get_data.dup

      return data if data[:error]

      total_value = data[:balance] + data[:totalPairsCurrentValue] + data[:totalDCACurrentValue]

      {
        market: data[:market],
        profit_today_btc: number_with_precision(data[:totalProfitToday], precision: 8),
        profit_today_pct: number_to_percentage(data[:totalProfitToday] / total_value * 100, precision: 2),
        profit_week_btc: number_with_precision(data[:totalProfitWeek], precision: 8),
        profit_week_pct: number_to_percentage(data[:totalProfitWeek] / total_value * 100, precision: 2),
        profit_yesterday_btc: number_with_precision(data[:totalProfitYesterday], precision: 8),
        profit_yesterday_pct: number_to_percentage(data[:totalProfitYesterday] / total_value * 100, precision: 2),
        total_value_btc: number_with_precision(total_value, precision: 8),
        total_value_usd: number_to_currency(total_value * data[:BTCUSDTPrice]),
      }.with_indifferent_access
    end

    def fetch_data_pairs
      data = get_data.dup

      return data if data[:error]

      (data[:gainLogData] || []).map do |pair|
        average_calc = pair[:averageCalculator]
        first_bought = average_calc[:firstBoughtDate]
        estimated_value_btc = average_calc[:totalAmount] * pair[:currentPrice]
        average_cost_btc = average_calc[:totalAmount] * average_calc[:avgPrice]

        {
          # sell_strat: pair[:sellStrategy],
          average_price_btc: number_with_precision(average_calc[:avgPrice], precision: 8),
          current_price_btc: number_with_precision(pair[:currentPrice], precision: 8),
          date: Date.parse(first_bought[:date].values.join("-")).to_s,
          estimated_value_usd: number_to_currency(estimated_value_btc * data[:BTCUSDTPrice]),
          market: pair[:market],
          profit_pct: number_to_percentage(pair[:profit], precision: 2),
          profit_usd: number_to_currency(pair[:profit] * average_cost_btc * data[:BTCUSDTPrice] * 0.01, precision: 2),
          total_amount: number_with_precision(average_calc[:totalAmount], precision: 8),
          volume: pair[:volume].to_i,
        }.with_indifferent_access
      end
    end

    def fetch_data_dca
      data = get_data.dup

      return data if data[:error]

      (data[:dcaLogData] || []).map do |dca|
        average_calc = dca[:averageCalculator]
        first_bought = average_calc[:firstBoughtDate]
        average_cost_btc = average_calc[:totalAmount] * average_calc[:avgPrice]

        {
          # profit_usd: dca[:profit],
          average_price_btc: number_with_precision(average_calc[:avgPrice], precision: 8),
          average_price_btc: number_with_precision(average_calc[:avgPrice], precision: 8),
          average_price_usd: number_to_currency(average_calc[:avgPrice] * data[:BTCUSDTPrice]),
          current_price_btc: number_with_precision(dca[:currentPrice], precision: 8),
          current_price_btc: number_with_precision(dca[:currentPrice], precision: 8),
          current_price_usd: number_to_currency(dca[:currentPrice] * data[:BTCUSDTPrice]),
          date: Date.parse(first_bought[:date].values.join("-")).to_s,
          dca_count: dca[:boughtTimes],
          estimated_value_btc: number_with_precision(average_calc[:totalAmount] * dca[:currentPrice], precision: 8),
          estimated_value_usd: number_to_currency(average_calc[:totalAmount] * dca[:currentPrice] * data[:BTCUSDTPrice]),
          market: dca[:market],
          profit_pct: number_to_percentage(dca[:profit], precision: 2),
          profit_usd: number_to_currency(dca[:profit] * average_cost_btc * data[:BTCUSDTPrice] * 0.01, precision: 2),
          total_amount: number_with_precision(average_calc[:totalAmount], precision: 8),
          volume: dca[:volume].to_i,
        }.with_indifferent_access
      end
    end

    def get_data
      begin
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

        json.select do |key, _value|
          keys.include?(key)
        end.
        with_indifferent_access
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

    # def fetch_data_pairs
    # end

    # def fetch_data_dca
    # end

    # def market
    #   data["market"]
    # end

    # def balance
    #   ("%.20f" % data["balance"]).to_f
    # end

    # def pairs_value
    #   ("%.20f" % data["totalPairsCurrentValue"]).to_f
    # end

    # def dca_value
    #   ("%.20f" % data["totalDCACurrentValue"]).to_f
    # end

    # def total_value
    #   (balance + pairs_value + dca_value).round(10)
    # end

    # def profit_today
    #   ("%.20f" % data["totalProfitToday"]).to_f.round(10)
    # end

    # def profit_yesterday
    #   ("%.20f" % data["totalProfitYesterday"]).to_f.round(10)
    # end

    # def profit_week
    #   ("%.20f" % data["totalProfitWeek"]).to_f.round(10)
    # end

    # def profit_today_pct
    #   (profit_today / total_value * 100.0).round(2)
    # end

    # def profit_yesterday_pct
    #   (profit_yesterday / total_value * 100.0).round(2)
    # end

    # def profit_week_pct
    #   (profit_week / total_value * 100.0).round(2)
    # end

    def error_message
      @_error_message ||= "There was a problem talking to ProfitTrailer. Check your settings and make sure ProfitTrailer is running."
    end

    # def pairs
    #   @_pairs ||= begin
    #     keys = [
    #       "market",
    #       "profit",
    #       "averageCalculator",
    #       "currentPrice",
    #       "sellStrategy",
    #       "volume",
    #       "triggerValue",
    #     ]

    #     (data["gainLogData"] || []).map do |pair|
    #       pair.select { |key, _value| keys.include?(key) }
    #     end
    #   end
    # end

    # def dcas
    #   @_dcas ||=
    #     begin
    #       keys = [
    #         "BBLow",
    #         "BBTrigger",
    #         "boughtTimes",
    #         "buyProfit",
    #         "market",
    #         "profit",
    #         "averageCalculator",
    #         "currentPrice",
    #         "volume",
    #         "triggerValue",
    #       ]

    #       (data["dcaLogData"] || []).map do |dca|
    #         dca.select { |key, _value| keys.include?(key) }
    #       end
    #     end
    # end

    private

    # def fetch_data
    #   @_data = nil
    #   @_pairs = nil
    #   @_dcas = nil
    # end


    # def som_on
    #   begin
    #     response = conn.get("/settings/overrideSellOnlyMode?enabled=false")
    #     response.status == 302
    #   rescue
    #     { error: error_message }
    #   end
    # end

    # def som_off
    #   begin
    #     response = conn.get("/settings/overrideSellOnlyMode")
    #     response.status == 302
    #   rescue
    #     { error: error_message }
    #   end
    # end

    # def stop_pt
    #   begin
    #     response = conn.get("/stop")
    #     response.status == 200
    #   rescue
    #     { error: error_message }
    #   end
    # end
  end
end
