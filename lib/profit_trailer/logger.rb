require "file/tail"
require "json"

class ProfitTrailer::Logger
  class << self
    def run(client:)
      File.open(ProfitTrailer.config["PT_LOG_FILE_PATH"]) do |log|
        log.extend(File::Tail)
        log.interval
        log.backward(0)
        log.tail do |line|
          parts = line.split(" ")
          log_type = parts[2]

          message =
            case log_type
            when "INFO" then process_info(parts)
            when "ERROR" then process_error(parts)
            else line
            end

          client.say(text: message, channel: ProfitTrailer.config["PT_LOGGER_SLACK_CHANNEL"])
          puts message
        end
      end
    end

    private

    def process_info(parts)
      raw_message = parts[5..-1].join(" ")
      service = parts[3]

      if raw_message == "DCA Heartbeat"
         "DCA :heart:" if show_heartbeats?
      elsif raw_message == "Cache Heartbeat"
         "Cache :heart:" if show_heartbeats?
      elsif raw_message == "Normal Heartbeat"
         "Normal :heart:" if show_heartbeats?
      elsif raw_message.include?("Get order information -- ")
        # {
        #   'symbol': 'ICXBTC',
        #   'price': 0.00071070,
        #   'status': 'EXPIRED',
        #   'type': 'LIMIT',
        #   'side': 'BUY',
        # }

        raw_json = raw_message.split("Get order information -- ").last
        parsed_json = JSON.parse(raw_json)

        symbol = parsed_json["symbol"]
        price = parsed_json["price"]
        status = parsed_json["status"]
        type = parsed_json["type"]
        side = parsed_json["side"]
        emoji = ""

        if status == "FILLED"
          status = "been _FILLED_"

          if show_emoji?
            if side == "BUY"
              emoji = ":chart_with_downwards_trend: "
            else
              emoji = ":chart_with_upwards_trend: "
            end
          end

          "#{emoji}The _#{type} #{side}_ order for *#{price}* of *#{symbol}* has #{status}"
        else
          emoji = ":warning: " if show_emoji?

          "#{emoji}The _#{type} #{side}_ order for #{price} of #{symbol} has _#{status}_"
        end
      elsif raw_message.include?("Buy order for ") || raw_message.include?("Sell order for ")
        # Buy order for VENBTC --
        # {
        #   'symbol': 'VENBTC',
        #   'price': '0.00071795',
        #   'status': 'FILLED',
        #   'type': 'LIMIT',
        #   'side': 'BUY'
        # }
        # Sell order for VENBTC sold amount 3.000000 for price 0.000725 --
        # {
        #   'symbol': 'VENBTC',
        #   'price': '0.00072519',
        #   'type': 'LIMIT',
        #   'side': 'SELL'
        # }

        raw_json = raw_message.split(" ").last
        parsed_json = JSON.parse(raw_json)

        symbol = parsed_json["symbol"]
        price = parsed_json["price"]
        type = parsed_json["type"]
        side = parsed_json["side"]
        emoji = show_emoji? ? ":zap: " : ""

        "#{emoji}Placing _#{type} #{side}_ order for #{price} of #{symbol}"
      elsif raw_message == "Detected configuration changes"
        emoji = show_emoji? ? ":memo: " : ""

        "#{emoji}#{raw_message}"
      elsif service == "DCAStrategyRunner"
        emoji = show_emoji? ? ":chart_with_downwards_trend: " : ""

        "#{emoji}#{raw_message}" if show_strategy_runners?
      elsif service == "NormalStrategyRunner"
        emoji = show_emoji? ? ":recycle: " : ""

        "#{emoji}#{raw_message}" if show_strategy_runners?
      else
        emoji = show_emoji? ? ":information_source: " : ""

        "#{emoji}#{raw_message}"
      end
    end

    def process_error(parts)
      raw_message = parts[5..-1].join(" ")
      emoji = show_emoji? ? ":x: " : ""

      "#{emoji}#{raw_message}"
    end

    def show_heartbeats?
      @_show_heartbeats ||= !(ProfitTrailer.config["PT_LOGGER_SHOW_HEARTBEATS"] == "false")
    end

    def show_emoji?
      @_show_emoji ||= !(ProfitTrailer.config["PT_LOGGER_SHOW_EMOJI"] == "false")
    end

    def show_strategy_runners?
      @_show_strategy_runners ||= !(ProfitTrailer.config["PT_LOGGER_SHOW_STRATEGY_RUNNERS"] == "false")
    end
  end
end
