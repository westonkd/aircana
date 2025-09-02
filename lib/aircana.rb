# frozen_string_literal: true

require "logger"
require_relative "aircana/version"
require_relative "aircana/configuration"
require_relative "aircana/cli"

module Aircana
  class Error < StandardError; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration if block_given?
    end

    def logger
      @logger ||= Logger.new($stdout)
    end

    def initialize!
      return if @initialized

      logger.debug "Aircana gem initialized"

      @initialized = true
    end
  end
end

Aircana.initialize!
