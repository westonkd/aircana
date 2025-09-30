# frozen_string_literal: true

# rubocop:disable Metrics/MethodLength, Metrics/AbcSize
module Aircana
  module CLI
    module Reviews
      class << self
        def show(commit_sha = nil)
          reviews_dir = Aircana.configuration.reviews_dir

          unless Dir.exist?(reviews_dir)
            Aircana.human_logger.error "No reviews directory found at #{reviews_dir}"
            return
          end

          if commit_sha
            show_specific_review(reviews_dir, commit_sha)
          else
            show_latest_review(reviews_dir)
          end
        end

        def list
          reviews_dir = Aircana.configuration.reviews_dir

          unless Dir.exist?(reviews_dir)
            Aircana.human_logger.error "No reviews directory found at #{reviews_dir}"
            return
          end

          reviews = Dir.glob(File.join(reviews_dir, "review-*.md"))
                       .reject { |f| File.symlink?(f) }
                       .sort_by { |f| File.mtime(f) }
                       .reverse

          if reviews.empty?
            Aircana.human_logger.info "No reviews found"
            return
          end

          Aircana.human_logger.info "Available reviews:"
          reviews.each do |review|
            filename = File.basename(review)
            mtime = File.mtime(review).strftime("%Y-%m-%d %H:%M:%S")
            Aircana.human_logger.info "  #{filename} (#{mtime})"
          end
        end

        private

        def show_latest_review(reviews_dir)
          latest_link = File.join(reviews_dir, "latest.md")

          if File.exist?(latest_link)
            display_review(latest_link)
          else
            # Fallback: find most recent review file
            reviews = Dir.glob(File.join(reviews_dir, "review-*.md"))
                         .reject { |f| File.symlink?(f) }
                         .sort_by { |f| File.mtime(f) }

            if reviews.empty?
              Aircana.human_logger.error "No reviews found"
            else
              display_review(reviews.last)
            end
          end
        end

        def show_specific_review(reviews_dir, commit_sha)
          # Find review file matching the commit SHA
          pattern = File.join(reviews_dir, "review-#{commit_sha}*.md")
          matches = Dir.glob(pattern).reject { |f| File.symlink?(f) }

          if matches.empty?
            Aircana.human_logger.error "No review found for commit #{commit_sha}"
          elsif matches.length == 1
            display_review(matches.first)
          else
            Aircana.human_logger.info "Multiple reviews found for #{commit_sha}:"
            matches.each do |match|
              Aircana.human_logger.info "  #{File.basename(match)}"
            end
            Aircana.human_logger.info "\nDisplaying most recent:"
            display_review(matches.max_by { |f| File.mtime(f) })
          end
        end

        def display_review(file_path)
          Aircana.human_logger.info "Review: #{File.basename(file_path)}\n"
          content = File.read(file_path)
          puts content
        end
      end
    end
  end
end
# rubocop:enable Metrics/MethodLength, Metrics/AbcSize
