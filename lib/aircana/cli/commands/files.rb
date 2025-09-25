# frozen_string_literal: true

require_relative "add_files"
require_relative "add_directory"
require_relative "clear_files"
require_relative "../../contexts/relevant_files"

module Aircana
  module CLI
    module Files
      class << self
        def add
          AddFiles.run
        end

        def add_dir(directory_path)
          AddDirectory.run(directory_path)
        end

        def clear
          ClearFiles.run
        end

        def list
          relevant_files_dir = Aircana.configuration.relevant_project_files_dir
          return print_no_directory_message unless Dir.exist?(relevant_files_dir)

          files = get_tracked_files(relevant_files_dir)
          return print_no_files_message if files.empty?

          print_files_list(files)
        end

        private

        def print_no_directory_message
          Aircana.human_logger.info(
            "No relevant files directory found. Use 'aircana files add' to start tracking files."
          )
        end

        def print_no_files_message
          Aircana.human_logger.info("No relevant files currently tracked.")
        end

        def get_tracked_files(relevant_files_dir)
          Dir.glob("#{relevant_files_dir}/*").map do |link|
            File.readlink(link)
          rescue StandardError
            link
          end
        end

        def print_files_list(files)
          Aircana.human_logger.info("Current relevant files:")
          files.each_with_index do |file, index|
            relative_path = file.start_with?(Dir.pwd) ? file.gsub("#{Dir.pwd}/", "") : file
            Aircana.human_logger.info("  #{index + 1}. #{relative_path}")
          end
          Aircana.human_logger.info("\nTotal: #{files.length} files")
        end
      end
    end
  end
end
