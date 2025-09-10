# frozen_string_literal: true

require_relative "../shell_command"
require_relative "../../contexts/relevant_files"

module Aircana
  module CLI
    module AddFiles
      class << self
        def run
          selected_files = FzfHelper.select_files_interactively(
            header: "Select files for Claude context (Ctrl+A: select all, ?: toggle preview)"
          )

          if selected_files.empty?
            Aircana.human_logger.info "No files selected. Exiting."
            return
          end

          Aircana.human_logger.success "Selected #{selected_files.size} files for context"
          Contexts::RelevantFiles.add(selected_files)
        end
      end
    end
  end
end
