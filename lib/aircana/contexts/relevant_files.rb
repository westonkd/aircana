# frozen_string_literal: true

module Aircana
  module Contexts
    class RelevantFiles
      class << self
        def to_s(verbose: false)
          create_dir_if_needed

          Dir.glob("#{Aircana.configuration.relevant_project_files_dir}/*").map do |file|
            real_path = File.realpath(file)
            content = File.read(file).to_s

            verbose ? "# In #{real_path}\n\n#{content}" : real_path
          end.join("\n")
        end

        def add(files)
          files = Array(files)

          create_dir_if_needed

          files.each do |file|
            absolute_file_path = File.expand_path(file)
            link_path = "#{Aircana.configuration.relevant_project_files_dir}/#{File.basename(file)}"

            File.unlink(link_path) if File.exist?(link_path)
            File.symlink(absolute_file_path, link_path)
          end
        end

        def remove(files)
          files = Array(files)

          files.each do |file|
            link_path = "#{Aircana.configuration.relevant_project_files_dir}/#{File.basename(file)}"
            File.unlink(link_path) if File.exist?(link_path)
          end
        end

        def remove_all
          return unless directory_exists?

          Dir.glob("#{Aircana.configuration.relevant_project_files_dir}/*").each do |file|
            File.unlink(file) if File.exist?(file)
          end
        end

        private

        def directory_exists?
          Dir.exist?(Aircana.configuration.relevant_project_files_dir)
        end

        def create_dir_if_needed
          # check if Aircana.configuration.relevant_project_files_dir exists. If not create it
          return if directory_exists?

          FileUtils.mkdir_p(Aircana.configuration.relevant_project_files_dir)
        end
      end
    end
  end
end
