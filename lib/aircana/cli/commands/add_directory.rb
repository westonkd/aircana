# frozen_string_literal: true

require "tty-prompt"
require_relative "../../contexts/relevant_files"

module Aircana
  module CLI
    module AddDirectory
      class << self
        def run(directory_path)
          return unless directory_valid?(directory_path)

          selected_files = collect_files_recursively(directory_path)
          return log_no_files_found(directory_path) if selected_files.empty?

          return unless confirm_large_operation(selected_files.size, directory_path)

          process_files(directory_path, selected_files)
        end

        private

        def directory_valid?(directory_path)
          unless File.directory?(directory_path)
            Aircana.human_logger.error "Directory not found: #{directory_path}"
            return false
          end

          unless File.readable?(directory_path)
            Aircana.human_logger.error "Directory not readable: #{directory_path}"
            return false
          end

          true
        end

        def log_no_files_found(directory_path)
          Aircana.human_logger.info "No files found in directory: #{directory_path}"
        end

        def confirm_large_operation(file_count, directory_path)
          if file_count > 50
            prompt = TTY::Prompt.new

            estimated_size = estimate_total_size(directory_path, file_count)
            Aircana.human_logger.warn "Large directory operation detected:"
            Aircana.human_logger.info "  Directory: #{directory_path}"
            Aircana.human_logger.info "  Files: #{file_count}"
            Aircana.human_logger.info "  Estimated size: #{estimated_size}"
            Aircana.human_logger.warn "  This may result in high token usage with Claude"

            prompt.yes?("Continue with adding #{file_count} files?")
          else
            true
          end
        end

        def estimate_total_size(directory_path, file_count)
          sample_files = Dir.glob(File.join(directory_path, "**", "*"))
                            .reject { |f| File.directory?(f) }
                            .sample([file_count, 10].min)

          return "Unknown" if sample_files.empty?

          total_bytes = sample_files.sum do |f|
            File.size(f)
          rescue StandardError
            0
          end
          avg_size = total_bytes / sample_files.size.to_f
          estimated_total = (avg_size * file_count).to_i

          format_file_size(estimated_total)
        end

        def format_file_size(bytes)
          units = %w[B KB MB GB]
          size = bytes.to_f
          unit_index = 0

          while size >= 1024 && unit_index < units.length - 1
            size /= 1024
            unit_index += 1
          end

          "#{size.round(1)} #{units[unit_index]}"
        end

        def process_files(directory_path, selected_files)
          file_count = selected_files.length
          Aircana.human_logger.info "Found #{file_count} files in directory: #{directory_path}"

          ProgressTracker.with_spinner("Adding #{file_count} files to context") do
            Contexts::RelevantFiles.add(selected_files)
          end

          Aircana.human_logger.success "Successfully added #{file_count} files from directory"
        end

        def log_token_warning(file_count)
          Aircana.human_logger.warn "Large number of files (#{file_count}) may result in high token usage"
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
