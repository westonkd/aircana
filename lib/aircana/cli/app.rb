# frozen_string_literal: true

require "thor"
require_relative "./commands/add_files"
require_relative "./commands/clear_files"
require_relative "./commands/dump_context"

module Aircana
  module CLI
    # Thor application for the primary cli
    class App < Thor
      package_name "Aircana"

      # TODO: Decide how to represent and store file groups
      desc "add files to 'relevant files'",
           "interactively add files or file groups to the current context. Use tab to mark multiple files."
      def add_files
        AddFiles.run
      end

      desc "clear files from 'relevant files'",
           "Removes all files from the current set of 'relevant files'"
      def clear_files
        ClearFiles.run
      end

      desc "dump context for the specified agent",
           "dumps relevant files, knowledge, memories, and decisions for the specified agent"
      option :verbose, type: :boolean, default: true
      def dump_context(agent_name)
        DumpContext.run(agent_name: agent_name, verbose: options[:verbose])
      end
    end
  end
end
