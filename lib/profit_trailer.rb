require "parseconfig"

class ProfitTrailer
  class << self
    def config
      @_config ||= ParseConfig.new(File.join(File.dirname(__FILE__), "../app.config"))
    end
  end
end

require_relative "profit_trailer/api"
require_relative "profit_trailer/bot"
require_relative "profit_trailer/logger"
