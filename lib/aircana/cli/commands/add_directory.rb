# frozen_string_literal: true

require_relative "../../contexts/relevant_files"

module Aircana
  module CLI
    module AddDirectory
      class << self
        def run(directory_path)
          return unless directory_valid?(directory_path)

          selected_files = collect_files_recursively(directory_path)
          return log_no_files_found(directory_path) if selected_files.empty?

          process_files(directory_path, selected_files)
        end

        private

        def directory_valid?(directory_path)
          unless File.directory?(directory_path)
            Aircana.logger.error "Directory not found: #{directory_path}"
            return false
          end

          unless File.readable?(directory_path)
            Aircana.logger.error "Directory not readable: #{directory_path}"
            return false
          end

          true
        end

        def log_no_files_found(directory_path)
          Aircana.logger.info "No files found in directory: #{directory_path}"
        end

        def process_files(directory_path, selected_files)
          file_count = selected_files.length
          Aircana.logger.info "Found #{file_count} files in directory: #{directory_path}"

          log_token_warning(file_count) if file_count > 100

          Contexts::RelevantFiles.add(selected_files)

          Aircana.logger.info "Successfully added #{file_count} files from directory"
        end

        def log_token_warning(file_count)
          Aircana.logger.warn "Large number of files (#{file_count}) may result in high token usage"
        end

        def collect_files_recursively(directory_path)
          Dir.glob(File.join(directory_path, "**", "*"), File::FNM_DOTMATCH)
             .reject { |path| File.directory?(path) }
             .reject { |path| should_ignore_file?(path) }
        end

        def should_ignore_file?(file_path)
          ignore_patterns.any? { |pattern| file_path.match?(pattern) }
        end

        def ignore_patterns
          directory_patterns + file_patterns
        end

        def directory_patterns
          [
            %r{/\.git/}, %r{/node_modules/}, %r{/\.vscode/}, %r{/\.idea/},
            %r{/coverage/}, %r{/dist/}, %r{/build/}, %r{/tmp/}, %r{/vendor/},
            %r{/\.bundle/}, %r{/\.rvm/}, %r{/\.rbenv/}
          ]
        end

        def file_patterns
          [
            %r{/\.DS_Store$}, %r{/log/.*\.log$},
            /\.(jpg|jpeg|png|gif|bmp|tiff|svg|ico|webp)$/i,
            /\.(mp4|avi|mkv|mov|wmv|flv|webm)$/i,
            /\.(mp3|wav|flac|aac|ogg)$/i,
            /\.(zip|tar|gz|rar|7z|bz2)$/i,
            /\.(exe|dll|so|dylib)$/i
          ]
        end
      end
    end
  end
end
