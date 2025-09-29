# frozen_string_literal: true

require_relative "../shell_command"

module Aircana
  module CLI
    module DumpContext
      class << self
        def run(_agent_name:, _verbose: true)
          Aircana.logger.level = Logger::ERROR
          Aircana.human_logger.info("Context dumping functionality has been removed.")
        end

        private

        def print(context)
          Aircana.configuration.stream.puts context
        end
      end
    end
  end
end
