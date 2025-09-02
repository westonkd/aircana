# frozen_string_literal: true

require_relative "../shell_command"
require_relative "../../contexts/relevant_files"

module Aircana
  module CLI
    module ClearFiles
      class << self
        def run
          Contexts::RelevantFiles.remove_all
        end
      end
    end
  end
end
