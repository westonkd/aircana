# frozen_string_literal: true

require "thor"
require_relative "./commands/add_relevant_files"

module Arcana
  module CLI
    # Thor application for the primary cli
    class App < Thor
      package_name "Aircana"

      def add_files
        CLI::AddFiles.run
      end
    end
  end
end
