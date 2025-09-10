# frozen_string_literal: true

module Aircana
  class Configuration
    attr_accessor :global_dir, :project_dir, :relevant_project_files_dir, :stream, :output_dir,
                  :claude_code_config_path, :claude_code_project_config_path, :agent_knowledge_dir,
                  :confluence_base_url, :confluence_username, :confluence_api_token

    def initialize
      # Global configuration directory for Aircana
      @global_dir = File.join(Dir.home, ".aircana")

      # Project-specific configuration directory for Aircana
      @project_dir = Dir.pwd

      # Where are links to relevant project files stored?
      @relevant_project_files_dir = File.join(@project_dir, ".aircana", "relevant_files")

      # Where should `generate` write files by default?
      @output_dir = File.join(@global_dir, "aircana.out")

      # Where is claude code's configuration stored?
      @claude_code_config_path = File.join(Dir.home, ".claude")

      # Where is claude code's project configuration stored?
      @claude_code_project_config_path = File.join(Dir.pwd, ".claude")

      # Default stream to write command output to
      @stream = $stdout

      # Where are agent knowledge files stored?
      @agent_knowledge_dir = File.join(@project_dir, ".aircana", "agents")

      # Confluence API configuration
      @confluence_base_url = nil
      @confluence_username = nil
      @confluence_api_token = nil
    end
  end
end
