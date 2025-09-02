# frozen_string_literal: true

module Aircana
  class Configuration
    attr_accessor :global_dir, :project_dir, :relevant_project_files_dir, :stream, :output_dir

    def initialize
      # Global configuration directory for Aircana
      @global_dir = File.expand_path("~/.aircana")

      # Project-specific configuration directory for Aircana
      @project_dir = Dir.pwd

      # Where are links to relevant project files stored?
      @relevant_project_files_dir = File.join(@project_dir, "relevant_files")

      # Where should `generate` write files by default?
      @output_dir = File.join(@global_dir, "aircana.out")

      # Default stream to write command output to
      @stream = $stdout
    end
  end
end
