# frozen_string_literal: true

require_relative "../../generators/relevant_files_command_generator"
require_relative "../../generators/relevant_files_verbose_results_generator"

module Aircana
  module CLI
    module Generate
      class << self
        def generators
          @generators ||= [
            Aircana::Generators::RelevantFilesVerboseResultsGenerator.new,
            Aircana::Generators::RelevantFilesCommandGenerator.new
          ]
        end

        def run
          generators.each(&:generate)
          Aircana.logger.info("Re-generated #{Aircana.configuration.output_dir} files.")
        end
      end
    end
  end
end
