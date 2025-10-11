# frozen_string_literal: true

module Aircana
  class Configuration
    attr_accessor :global_dir, :project_dir, :stream, :output_dir,
                  :claude_code_config_path, :claude_code_project_config_path, :agent_knowledge_dir,
                  :hooks_dir, :scripts_dir, :confluence_base_url, :confluence_username, :confluence_api_token,
                  :plugin_root, :plugin_manifest_dir, :commands_dir, :agents_dir

    def initialize
      setup_directory_paths
      setup_plugin_paths
      setup_claude_code_paths
      setup_stream
      setup_confluence_config
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

    private

    def setup_directory_paths
      @global_dir = File.join(Dir.home, ".aircana")
      @project_dir = Dir.pwd
      @output_dir = File.join(@global_dir, "aircana.out")
    end

    def setup_plugin_paths
      # Plugin root is the project directory by default
      @plugin_root = @project_dir
      @plugin_manifest_dir = File.join(@plugin_root, ".claude-plugin")
      @commands_dir = File.join(@plugin_root, "commands")
      @agents_dir = File.join(@plugin_root, "agents")
      @hooks_dir = File.join(@plugin_root, "hooks")
      @scripts_dir = File.join(@plugin_root, "scripts")
      @agent_knowledge_dir = File.join(@plugin_root, "agents")
    end

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
  end
end
