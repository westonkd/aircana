# frozen_string_literal: true

require "logger"
require "fileutils"
require_relative "aircana/version"
require_relative "aircana/configuration"
require_relative "aircana/cli"
require_relative "aircana/generators"
require_relative "aircana/contexts/confluence"
require_relative "aircana/contexts/local"

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

      create_dir_if_needed(configuration.relevant_project_files_dir)

      @initialized = true
    end

    def create_dir_if_needed(directory)
      return if Dir.exist?(directory)

      FileUtils.mkdir_p(directory)
    end
  end
end

Aircana.initialize!
