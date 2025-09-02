# frozen_string_literal: true

require_relative "../shell_command"
require_relative "../../contexts/relevant_files"

module Aircana
  module CLI
    module AddFiles
      class << self
        def run
          selected_files = ShellCommand.run("fzf -m")

          selected_files = selected_files.split("\n").map(&:strip).reject(&:empty?)

          if selected_files.empty?
            Aircana.logger.info "No files selected. Exiting."
            return
          end

          # For now remove all files from the relevant files context, but consider
          # making this a more explicit action
          Contexts::RelevantFiles.remove_all
          Contexts::RelevantFiles.add(selected_files)
        end
      end
    end
  end
end
