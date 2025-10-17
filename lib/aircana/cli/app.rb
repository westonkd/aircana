# frozen_string_literal: true

require "thor"

require_relative "commands/doctor"
require_relative "commands/dump_context"
require_relative "commands/generate"
require_relative "commands/init"

require_relative "subcommand"
require_relative "help_formatter"
require_relative "commands/kb"
require_relative "commands/hooks"
require_relative "commands/plugin"

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
           "dumps knowledge, memories, and decisions for the specified agent"
      option :verbose, type: :boolean, default: true
      def dump_context(agent_name)
        DumpContext.run(agent_name: agent_name, verbose: options[:verbose])
      end

      desc "generate", "Generates all configured files and dumps the configured output directory"
      def generate
        Generate.run
      end

      desc "init [DIRECTORY]",
           "Initializes a Claude Code plugin in the specified directory (defaults to current directory)"
      option :plugin_name, type: :string, desc: "Override the default plugin name"
      def init(directory = nil)
        Init.run(directory: directory, plugin_name: options[:plugin_name])
      end

      class KBSubcommand < Subcommand
        desc "create", "Create a new knowledge base"
        def create
          KB.create
        end

        desc "refresh KB_NAME", "Refresh knowledge base from Confluence/web sources"
        def refresh(kb_name)
          KB.refresh(kb_name)
        end

        desc "list", "List all configured knowledge bases"
        def list
          KB.list
        end

        desc "add-url KB_NAME URL", "Add a web URL to a knowledge base"
        def add_url(kb_name, url)
          KB.add_url(kb_name, url)
        end

        desc "refresh-all", "Refresh all remote knowledge bases"
        def refresh_all
          KB.refresh_all
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

      desc "kb", "Create and manage knowledge bases for Claude Code skills"
      subcommand "kb", KBSubcommand

      desc "hooks", "Manage Claude Code hooks"
      subcommand "hooks", HooksSubcommand

      class PluginSubcommand < Subcommand
        desc "info", "Display plugin information"
        def info
          Plugin.info
        end

        desc "update", "Update plugin metadata"
        def update
          Plugin.update
        end

        desc "version [ACTION] [TYPE]", "Manage plugin version (show, bump [major|minor|patch], or set)"
        def version(action = nil, bump_type = nil)
          Plugin.version(action, bump_type)
        end

        desc "validate", "Validate plugin structure and manifests"
        def validate
          Plugin.validate
        end
      end

      desc "plugin", "Manage plugin metadata and configuration"
      subcommand "plugin", PluginSubcommand
    end
  end
end
