# frozen_string_literal: true

require "logger"
require "fileutils"
require_relative "aircana/version"
require_relative "aircana/configuration"
require_relative "aircana/human_logger"
require_relative "aircana/fzf_helper"
require_relative "aircana/system_checker"
require_relative "aircana/progress_tracker"
require_relative "aircana/cli"
require_relative "aircana/generators"
require_relative "aircana/contexts/confluence"
require_relative "aircana/contexts/local"
require_relative "aircana/llm/base"
require_relative "aircana/llm/claude_client"

module Aircana
  module LLM
    class << self
      def client
        case provider
        when "bedrock"
          require_relative "aircana/llm/bedrock_client"
          BedrockClient.new
        when "claude", nil
          ClaudeClient.new
        else
          Aircana.human_logger.warn("Unknown LLM provider '#{provider}', falling back to Claude")
          ClaudeClient.new
        end
      end

      private

      def provider
        Aircana.configuration.llm_provider
      end
    end
  end

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

    def human_logger
      @human_logger ||= HumanLogger.new
    end

    def initialize!
      return if @initialized

      @initialized = true
    end

    def create_dir_if_needed(directory)
      return if Dir.exist?(directory)

      FileUtils.mkdir_p(directory)
    end
  end
end

Aircana.initialize!
