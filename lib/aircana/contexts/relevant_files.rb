# frozen_string_literal: true

module Aircana
  module Contexts
    class RelevantFiles
      class << self
        # TODO: Honor the provided verbose flag
        def print(verbose: false)
          verbose_generator(default_stream: true).generate
        end

        def add(files)
          files = Array(files)

          return if files.empty?

          Aircana.create_dir_if_needed(Aircana.configuration.relevant_project_files_dir)

          files.each do |file|
            absolute_file_path = File.expand_path(file)
            link_path = "#{Aircana.configuration.relevant_project_files_dir}/#{File.basename(file)}"

            File.unlink(link_path) if File.exist?(link_path)
            File.symlink(absolute_file_path, link_path)
          end

          rewrite_verbose_file
        end

        def remove(files)
          files = Array(files)

          return if files.empty?

          Aircana.create_dir_if_needed(Aircana.configuration.relevant_project_files_dir)

          files.each do |file|
            link_path = "#{Aircana.configuration.relevant_project_files_dir}/#{File.basename(file)}"
            File.unlink(link_path) if File.exist?(link_path)
          end

          rewrite_verbose_file
        end

        def remove_all
          return unless directory_exists?

          Dir.glob("#{Aircana.configuration.relevant_project_files_dir}/*").each do |file|
            File.unlink(file) if File.exist?(file)
          end

          return unless Dir.empty?(Aircana.configuration.relevant_project_files_dir)

          Dir.rmdir(Aircana.configuration.relevant_project_files_dir)
        end

        private

        def rewrite_verbose_file
          verbose_generator.generate
        end

        def verbose_generator(default_stream: false)
          Generators::RelevantFilesVerboseResultsGenerator.new(
            file_out: default_stream ? Aircana.configuration.stream : nil
          )
        end

        def directory_exists?
          Dir.exist?(Aircana.configuration.relevant_project_files_dir)
        end
      end
    end
  end
end
