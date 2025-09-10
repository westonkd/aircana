# frozen_string_literal: true

module Aircana
  module CLI
    class ShellCommand
      def self.run(command_string)
        # Command execution logged by human_logger elsewhere if needed

        `#{command_string}`
      end
    end
  end
end
