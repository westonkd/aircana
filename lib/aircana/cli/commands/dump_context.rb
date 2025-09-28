# frozen_string_literal: true

require_relative "../shell_command"

module Aircana
  module CLI
    module DumpContext
      class << self
        def run(agent_name:, verbose: true) # rubocop:disable Lint/UnusedMethodArgument
          Aircana.logger.level = Logger::ERROR
          Aircana.human_logger.info("Agent: #{agent_name}")
          Aircana.human_logger.info("Context dumping functionality has been removed.")
          Aircana.human_logger.info("This command previously dumped relevant files context.")
        end
      end
    end
  end
end
