# frozen_string_literal: true

require_relative "../shell_command"
require_relative "../../contexts/relevant_files"

module Aircana
  module CLI
    module DumpContext
      class << self
        def run(_agent_name:, verbose: true)
          Aircana.logger.level = Logger::ERROR
          Contexts::RelevantFiles.print(verbose:)
        end

        private

        def print(context)
          Aircana.configuration.stream.puts context
        end
      end
    end
  end
end
