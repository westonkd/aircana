# frozen_string_literal: true

require "json"

module Aircana
  class Configuration
    attr_accessor :global_dir, :project_dir, :stream, :output_dir,
                  :claude_code_config_path, :claude_code_project_config_path, :kb_knowledge_dir,
                  :hooks_dir, :scripts_dir, :confluence_base_url, :confluence_username, :confluence_api_token,
                  :plugin_root, :plugin_manifest_dir, :commands_dir, :skills_dir, :agents_dir,
                  :llm_provider, :bedrock_region, :bedrock_model

    def initialize
      setup_directory_paths
      setup_plugin_paths
      setup_claude_code_paths
      setup_stream
      setup_confluence_config
      setup_llm_config
    end

    # Returns true if the current directory is a plugin (has .claude-plugin/plugin.json)
    def plugin_mode?
      File.exist?(File.join(@plugin_root, ".claude-plugin", "plugin.json"))
    end

    # Returns the path to the plugin manifest file
    def plugin_manifest_path
      File.join(@plugin_manifest_dir, "plugin.json")
    end

    # Returns the path to the hooks manifest file
    def hooks_manifest_path
      File.join(@hooks_dir, "hooks.json")
    end

    # Returns the plugin name from plugin.json, or falls back to directory name
    def plugin_name
      return @plugin_name if defined?(@plugin_name)

      @plugin_name = if plugin_mode?
                       manifest = JSON.parse(File.read(plugin_manifest_path))
                       manifest["name"]
                     else
                       # Fallback to directory name if not in plugin mode
                       File.basename(@plugin_root).downcase.gsub(/[^a-z0-9]+/, "-")
                     end
    rescue StandardError
      # If anything fails, use directory name as fallback
      File.basename(@plugin_root).downcase.gsub(/[^a-z0-9]+/, "-")
    end

    # Returns the knowledge directory path for a KB
    # Format: .claude/skills/<kb-name>/
    # All knowledge files stored directly in the skill directory
    def kb_path(kb_name)
      File.join(@skills_dir, kb_name)
    end

    # Returns the knowledge directory for a specific KB (same as kb_path for now)
    # Kept for API compatibility during refactoring
    def kb_knowledge_path(kb_name)
      kb_path(kb_name)
    end

    private

    def setup_directory_paths
      @global_dir = File.join(Dir.home, ".aircana")
      @project_dir = Dir.pwd
      @output_dir = File.join(@global_dir, "aircana.out")
    end

    # rubocop:disable Metrics/MethodLength
    def setup_plugin_paths
      # Plugin root can be set via AIRCANA_PLUGIN_ROOT (for hooks) or CLAUDE_PLUGIN_ROOT,
      # otherwise defaults to the current project directory
      @plugin_root = ENV.fetch("AIRCANA_PLUGIN_ROOT", ENV.fetch("CLAUDE_PLUGIN_ROOT", @project_dir))
      @plugin_manifest_dir = File.join(@plugin_root, ".claude-plugin")
      @commands_dir = File.join(@plugin_root, "commands")

      # Skills directory location depends on whether we're in a plugin
      # Plugin mode: skills/ (Claude Code standard location)
      # Non-plugin mode: .claude/skills/ (local development/one-off usage)
      @skills_dir = if plugin_mode?
                      File.join(@plugin_root, "skills")
                    else
                      File.join(@plugin_root, ".claude", "skills")
                    end

      # Agents directory location depends on whether we're in a plugin
      # Plugin mode: agents/ (Claude Code standard location)
      # Non-plugin mode: .claude/agents/ (local development/one-off usage)
      @agents_dir = if plugin_mode?
                      File.join(@plugin_root, "agents")
                    else
                      File.join(@plugin_root, ".claude", "agents")
                    end

      @hooks_dir = File.join(@plugin_root, "hooks")
      @scripts_dir = File.join(@plugin_root, "scripts")
      @kb_knowledge_dir = @skills_dir
    end
    # rubocop:enable Metrics/MethodLength

    def setup_claude_code_paths
      @claude_code_config_path = File.join(Dir.home, ".claude")
      # For backward compatibility, keep this but plugin mode uses plugin_root
      @claude_code_project_config_path = File.join(Dir.pwd, ".claude")
    end

    def setup_stream
      @stream = $stdout
    end

    def setup_confluence_config
      @confluence_base_url = nil
      @confluence_username = nil
      @confluence_api_token = nil
    end

    def setup_llm_config
      @llm_provider = nil
      @bedrock_region = nil
      @bedrock_model = nil
    end
  end
end
