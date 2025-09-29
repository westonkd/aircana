# frozen_string_literal: true

require "thor"

require_relative "commands/doctor"
require_relative "commands/dump_context"
require_relative "commands/generate"
require_relative "commands/install"

require_relative "subcommand"
require_relative "help_formatter"
require_relative "commands/agents"
require_relative "commands/hooks"
require_relative "commands/project"

module Aircana
  module CLI
    # Thor application for the primary cli
    class App < Thor
      include HelpFormatter

      package_name "Aircana"

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

      class AgentsSubcommand < Subcommand
        desc "create", "Create a new agent"
        def create
          Agents.create
        end

        desc "refresh AGENT", "Refresh agent knowledge from Confluence pages with matching labels"
        def refresh(agent)
          Agents.refresh(agent)
        end

        desc "list", "List all configured agents"
        def list
          Agents.list
        end

        desc "add-url AGENT URL", "Add a web URL to an agent's knowledge base"
        def add_url(agent, url)
          Agents.add_url(agent, url)
        end

        desc "refresh-all", "Refresh knowledge for all configured agents"
        def refresh_all
          Agents.refresh_all
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

      class ProjectSubcommand < Subcommand
        desc "init", "Initialize project.json for multi-root support"
        def init
          Project.init
        end

        desc "add FOLDER_PATH", "Add a folder to multi-root configuration"
        def add(folder_path)
          Project.add(folder_path)
        end

        desc "remove FOLDER_PATH", "Remove a folder from multi-root configuration"
        def remove(folder_path)
          Project.remove(folder_path)
        end

        desc "list", "List all configured folders and their agents"
        def list
          Project.list
        end

        desc "sync", "Manually sync symlinks for multi-root agents"
        def sync
          Project.sync
        end
      end

      desc "agents", "Create and manage agents and their knowledgebases"
      subcommand "agents", AgentsSubcommand

      desc "hooks", "Manage Claude Code hooks"
      subcommand "hooks", HooksSubcommand

      desc "project", "Manage multi-root project configuration"
      subcommand "project", ProjectSubcommand
    end
  end
end
