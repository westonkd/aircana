# frozen_string_literal: true

module Aircana
  class Configuration
    attr_accessor :global_dir, :project_dir, :relevant_project_files_dir, :stream

    def initialize
      @global_dir = File.expand_path("~/.aircana")
      @project_dir = Dir.pwd
      @relevant_project_files_dir = File.join(@project_dir, "relevant_files")

      @stream = $stdout
    end
  end
end
