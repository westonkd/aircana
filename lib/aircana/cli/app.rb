# frozen_string_literal: true

require "thor"
require_relative "./commands/add_files"

module Aircana
  module CLI
    # Thor application for the primary cli
    class App < Thor
      package_name "Aircana"

      # TODO: Decide how to represent and store file groups
      #
      # Beyond that, how do we store that kind of config in a shared way in general?
      #
      # Use this gem in another that is Company-specific?
      desc "add files to context", "interactively add files or file groups to the current context"
      def add_files
        CLI::AddFiles.run
      end
    end
  end
end
