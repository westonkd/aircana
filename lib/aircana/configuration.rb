# frozen_string_literal: true

module Aircana
  class Configuration
    attr_accessor :global_dir, :project_dir, :stream, :output_dir,
                  :claude_code_config_path, :claude_code_project_config_path, :agent_knowledge_dir,
                  :hooks_dir, :confluence_base_url, :confluence_username, :confluence_api_token

    def initialize
      setup_directory_paths
      setup_claude_code_paths
      setup_stream
      setup_confluence_config
    end

    private

    def setup_directory_paths
      @global_dir = File.join(Dir.home, ".aircana")
      @project_dir = Dir.pwd
      @output_dir = File.join(@global_dir, "aircana.out")
      @agent_knowledge_dir = File.join(@project_dir, ".claude", "agents")
      @hooks_dir = File.join(@project_dir, ".aircana", "hooks")
    end

    def setup_claude_code_paths
      @claude_code_config_path = File.join(Dir.home, ".claude")
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
