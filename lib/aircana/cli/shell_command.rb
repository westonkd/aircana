# frozen_string_literal: true

module Aircana
  module CLI
    class ShellCommand
      def self.run(command_string)
        Aircana.logger.info("Running `#{command_string}`")

        `#{command_string}`
      end
    end
  end
end
