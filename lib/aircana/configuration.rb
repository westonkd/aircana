# frozen_string_literal: true

module Aircana
  class Configuration
    attr_accessor :global_dir, :project_dir, :relevant_project_files_dir, :stream, :output_dir, :claude_code_config_path

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

      # Default stream to write command output to
      @stream = $stdout
    end
  end
end
