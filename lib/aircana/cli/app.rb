# frozen_string_literal: true

require "thor"

require_relative "commands/add_files"
require_relative "commands/add_directory"
require_relative "commands/clear_files"
require_relative "commands/dump_context"
require_relative "commands/generate"
require_relative "commands/install"

require_relative "subcommand"
require_relative "commands/agents"

module Aircana
  module CLI
    # Thor application for the primary cli
    class App < Thor
      package_name "Aircana"

      # TODO: Decide how to represent and store file groups
      desc "add-files",
           "interactively add files or file groups to the current context. Use tab to mark multiple files."
      def add_files
        AddFiles.run
      end

      desc "add-dir [DIRECTORY_PATH]",
           "add all files from the specified directory recursively to the current context"
      def add_dir(directory_path)
        AddDirectory.run(directory_path)
      end

      desc "clear-files",
           "Removes all files from the current set of 'relevant files'"
      def clear_files
        ClearFiles.run
      end

      desc "dump-context",
           "dumps relevant files, knowledge, memories, and decisions for the specified agent"
      option :verbose, type: :boolean, default: true
      def dump_context(agent_name)
        DumpContext.run(agent_name: agent_name, verbose: options[:verbose])
      end

      desc "generate", "Generates all configured files and dumps the configured output directory"
      def generate
        Generate.run
      end

      desc "install", "Copies the generated files from `generate` to the proper directories in Claude Code config."
      def install
        Install.run
      end

      class AgentsSubcommand < Subcommand
        desc "create", "Create a new agent"
        def create
          Agents.create
        end
      end

      desc "agents", "Create and manage agents and their knowledgebases"
      subcommand "agents", AgentsSubcommand
    end
  end
end
