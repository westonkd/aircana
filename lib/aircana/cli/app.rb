# frozen_string_literal: true

require "thor"

require_relative "commands/add_files"
require_relative "commands/add_directory"
require_relative "commands/clear_files"
require_relative "commands/doctor"
require_relative "commands/dump_context"
require_relative "commands/generate"
require_relative "commands/install"
require_relative "commands/plan"
require_relative "commands/work"

require_relative "subcommand"
require_relative "commands/agents"
require_relative "commands/hooks"

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

      desc "doctor", "Check system health and validate all dependencies"
      option :verbose, type: :boolean, default: false, desc: "Show detailed information about optional dependencies"
      def doctor
        exit_code = Doctor.run(verbose: options[:verbose])
        exit(exit_code)
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

      desc "plan", "Launch Claude Code with planner agent for Jira ticket planning"
      def plan
        Plan.run
      end

      desc "work", "Launch Claude Code with worker agent for Jira ticket implementation"
      def work
        Work.run
      end

      class AgentsSubcommand < Subcommand
        desc "create", "Create a new agent"
        def create
          Agents.create
        end

        desc "refresh AGENT", "Refresh agent knowledge from Confluence pages with matching labels"
        def refresh(agent)
          Agents.refresh(agent)
        end
      end

      class HooksSubcommand < Subcommand
        desc "list", "List all available and installed hooks"
        def list
          Hooks.list
        end

        desc "enable HOOK_NAME", "Enable a specific hook"
        def enable(hook_name)
          Hooks.enable(hook_name)
        end

        desc "disable HOOK_NAME", "Disable a specific hook"
        def disable(hook_name)
          Hooks.disable(hook_name)
        end

        desc "create", "Create a new custom hook"
        def create
          Hooks.create
        end

        desc "status", "Show current hook configuration status"
        def status
          Hooks.status
        end
      end

      desc "agents", "Create and manage agents and their knowledgebases"
      subcommand "agents", AgentsSubcommand

      desc "hooks", "Manage Claude Code hooks"
      subcommand "hooks", HooksSubcommand
    end
  end
end
