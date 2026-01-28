# frozen_string_literal: true

require "json"
require "tty-prompt"
require_relative "../../generators/skills_generator"
require_relative "../../generators/agents_generator"
require_relative "../../contexts/manifest"
require_relative "../../contexts/web"

module Aircana
  module CLI
    module KB # rubocop:disable Metrics/ModuleLength
      class << self # rubocop:disable Metrics/ClassLength
        def refresh(kb_name)
          normalized_kb_name = normalize_string(kb_name)

          perform_manifest_aware_refresh(normalized_kb_name)
          regenerate_skill_md(normalized_kb_name)
          regenerate_agent_md(normalized_kb_name)
        rescue Aircana::Error => e
          handle_refresh_error(normalized_kb_name, e)
        end

        def create # rubocop:disable Metrics/MethodLength
          prompt = TTY::Prompt.new

          kb_name = prompt.ask("What topic should this knowledge base cover?",
                               default: "e.g., 'Canvas Backend Database', 'API Design'")
          short_description = prompt.ask("Briefly describe what this KB contains:")

          normalized_kb_name = normalize_string(kb_name)

          fetched_confluence = prompt_for_knowledge_fetch(prompt, normalized_kb_name, short_description)

          fetched_urls = prompt_for_url_fetch(prompt, normalized_kb_name)

          unless fetched_confluence || fetched_urls
            regenerate_skill_md(normalized_kb_name, short_description)
            regenerate_agent_md(normalized_kb_name)
          end

          Aircana.human_logger.success "Knowledge base '#{kb_name}' setup complete!"
        end

        def list
          kb_dir = Aircana.configuration.kb_knowledge_dir
          return print_no_kbs_message unless Dir.exist?(kb_dir)

          kb_folders = find_kb_folders(kb_dir)
          return print_no_kbs_message if kb_folders.empty?

          print_kbs_list(kb_folders)
        end

        # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
        def add_url(kb_name, url)
          normalized_kb_name = normalize_string(kb_name)

          unless kb_exists?(normalized_kb_name)
            Aircana.human_logger.error "KB '#{kb_name}' not found. Use 'aircana kb list' to see available KBs."
            exit 1
          end

          web = Aircana::Contexts::Web.new
          result = web.fetch_url_for(kb_name: normalized_kb_name, url: url)

          if result
            existing_sources = Aircana::Contexts::Manifest.sources_from_manifest(normalized_kb_name)
            web_sources = existing_sources.select { |s| s["type"] == "web" }
            other_sources = existing_sources.reject { |s| s["type"] == "web" }

            if web_sources.any?
              web_sources.first["urls"] << result
            else
              web_sources = [{ "type" => "web", "urls" => [result] }]
            end

            all_sources = other_sources + web_sources
            Aircana::Contexts::Manifest.update_manifest(normalized_kb_name, all_sources)

            regenerate_skill_md(normalized_kb_name)
            regenerate_agent_md(normalized_kb_name)

            Aircana.human_logger.success "Successfully added URL to KB '#{kb_name}'"
          else
            Aircana.human_logger.error "Failed to fetch URL: #{url}"
            exit 1
          end
        rescue Aircana::Error => e
          Aircana.human_logger.error "Failed to add URL: #{e.message}"
          exit 1
        end
        # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity

        def refresh_all # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
          kb_names = all_kbs

          if kb_names.empty?
            Aircana.human_logger.info "No knowledge bases found to refresh."
            return
          end

          Aircana.human_logger.info "Starting refresh for #{kb_names.size} KB(s)..."

          results = {
            total: kb_names.size,
            successful: 0,
            failed: 0,
            total_pages: 0,
            failed_kbs: []
          }

          kb_names.each do |kb_name|
            result = refresh_single_kb(kb_name)
            if result[:success]
              results[:successful] += 1
              results[:total_pages] += result[:pages_count]
            else
              results[:failed] += 1
              results[:failed_kbs] << { name: kb_name, error: result[:error] }
            end
          end

          print_refresh_all_summary(results)
        end

        private

        def perform_refresh(normalized_kb_name, label: nil)
          confluence = Aircana::Contexts::Confluence.new
          result = confluence.fetch_pages_for(kb_name: normalized_kb_name, label: label)

          log_refresh_result(normalized_kb_name, result[:pages_count])
          result
        end

        def log_refresh_result(normalized_kb_name, pages_count)
          if pages_count.positive?
            Aircana.human_logger.success "Successfully refreshed #{pages_count} pages for KB '#{normalized_kb_name}'"
          else
            log_no_pages_found(normalized_kb_name)
          end
        end

        # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        def perform_manifest_aware_refresh(normalized_kb_name)
          total_pages = 0
          all_sources = []

          if Aircana::Contexts::Manifest.manifest_exists?(normalized_kb_name)
            Aircana.human_logger.info "Refreshing from knowledge manifest..."

            confluence = Aircana::Contexts::Confluence.new
            confluence_result = confluence.refresh_from_manifest(kb_name: normalized_kb_name)
            total_pages += confluence_result[:pages_count]
            all_sources.concat(confluence_result[:sources])

            web = Aircana::Contexts::Web.new
            web_result = web.refresh_web_sources(kb_name: normalized_kb_name)
            total_pages += web_result[:pages_count]
            all_sources.concat(web_result[:sources])
          else
            Aircana.human_logger.info "No manifest found, falling back to label-based search..."
            confluence = Aircana::Contexts::Confluence.new
            confluence_result = confluence.fetch_pages_for(kb_name: normalized_kb_name)
            total_pages += confluence_result[:pages_count]
            all_sources.concat(confluence_result[:sources])
          end

          Aircana::Contexts::Manifest.update_manifest(normalized_kb_name, all_sources) if all_sources.any?

          log_refresh_result(normalized_kb_name, total_pages)
          { pages_count: total_pages, sources: all_sources }
        end
        # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

        def regenerate_skill_md(kb_name, _short_description = nil)
          return unless Aircana::Contexts::Manifest.manifest_exists?(kb_name)

          # Always use from_manifest when manifest exists to ensure knowledge_files are loaded
          generator = Generators::SkillsGenerator.from_manifest(kb_name)

          generator.generate
          Aircana.human_logger.success "Generated SKILL.md for '#{kb_name}'"
        rescue StandardError => e
          Aircana.human_logger.warn "Failed to generate SKILL.md: #{e.message}"
        end

        def regenerate_agent_md(kb_name)
          return unless Aircana::Contexts::Manifest.manifest_exists?(kb_name)

          # Generate agent from manifest
          generator = Generators::AgentsGenerator.from_manifest(kb_name)

          generator.generate
          Aircana.human_logger.success "Generated agent for '#{kb_name}'"
        rescue StandardError => e
          Aircana.human_logger.warn "Failed to generate agent: #{e.message}"
        end

        def log_no_pages_found(normalized_kb_name)
          Aircana.human_logger.info "No pages found for KB '#{normalized_kb_name}'. " \
                                    "Make sure pages are labeled with '#{normalized_kb_name}' in Confluence."
        end

        def handle_refresh_error(normalized_kb_name, error)
          Aircana.human_logger.error "Failed to refresh KB '#{normalized_kb_name}': #{error.message}"
          exit 1
        end

        def normalize_string(string)
          string.strip.downcase.gsub(" ", "-")
        end

        # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
        def prompt_for_knowledge_fetch(prompt, normalized_kb_name, short_description)
          return false unless confluence_configured?

          if prompt.yes?("Would you like to fetch knowledge for this KB from Confluence now?")
            Aircana.human_logger.info "Fetching knowledge from Confluence..."

            use_custom_label = prompt.yes?("Use a custom Confluence label? (default: #{normalized_kb_name})")
            label = if use_custom_label
                      prompt.ask("Enter Confluence label:")
                    else
                      normalized_kb_name
                    end

            result = perform_refresh(normalized_kb_name, label: label)
            if result[:pages_count]&.positive?
              regenerate_skill_md(normalized_kb_name, short_description)
              regenerate_agent_md(normalized_kb_name)
              return true
            end
          else
            Aircana.human_logger.info(
              "Skipping knowledge fetch. You can run 'aircana kb refresh #{normalized_kb_name}' later."
            )
          end

          false
        rescue Aircana::Error => e
          Aircana.human_logger.warn "Failed to fetch knowledge: #{e.message}"
          Aircana.human_logger.info "You can try again later with 'aircana kb refresh #{normalized_kb_name}'"
          false
        end
        # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity

        # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        def prompt_for_url_fetch(prompt, normalized_kb_name)
          return false unless prompt.yes?("Would you like to add web URLs for this KB's knowledge base?")

          urls = []
          loop do
            url = prompt.ask("Enter URL (or press Enter to finish):")
            break if url.nil? || url.strip.empty?

            url = url.strip
            if valid_url?(url)
              urls << url
            else
              Aircana.human_logger.warn "Invalid URL format: #{url}. Please enter a valid HTTP or HTTPS URL."
            end
          end

          return false if urls.empty?

          begin
            Aircana.human_logger.info "Fetching #{urls.size} URL(s)..."
            web = Aircana::Contexts::Web.new
            result = web.fetch_urls_for(kb_name: normalized_kb_name, urls: urls)

            if result[:pages_count].positive?
              Aircana.human_logger.success "Successfully fetched #{result[:pages_count]} URL(s)"
              regenerate_skill_md(normalized_kb_name)
              regenerate_agent_md(normalized_kb_name)
              return true
            else
              Aircana.human_logger.warn "No URLs were successfully fetched"
            end
          rescue Aircana::Error => e
            Aircana.human_logger.warn "Failed to fetch URLs: #{e.message}"
            Aircana.human_logger.info(
              "You can add URLs later with 'aircana kb add-url #{normalized_kb_name} <URL>'"
            )
          end

          false
        end
        # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

        # rubocop:disable Metrics/AbcSize
        def confluence_configured?
          config = Aircana.configuration

          base_url_present = !config.confluence_base_url.nil? && !config.confluence_base_url.empty?
          username_present = !config.confluence_username.nil? && !config.confluence_username.empty?
          token_present = !config.confluence_api_token.nil? && !config.confluence_api_token.empty?

          base_url_present && username_present && token_present
        end
        # rubocop:enable Metrics/AbcSize

        def print_no_kbs_message
          Aircana.human_logger.info("No knowledge bases configured yet.")
        end

        def find_kb_folders(kb_dir)
          Dir.entries(kb_dir).select do |entry|
            path = File.join(kb_dir, entry)
            File.directory?(path) && !entry.start_with?(".")
          end.sort
        end

        def print_kbs_list(kb_folders)
          Aircana.human_logger.info("Configured knowledge bases:")
          kb_folders.each_with_index do |kb_name, index|
            sources_count = get_sources_count(kb_name)
            Aircana.human_logger.info("  #{index + 1}. #{kb_name} (#{sources_count} sources)")
          end
          Aircana.human_logger.info("\nTotal: #{kb_folders.length} knowledge bases")
        end

        def get_sources_count(kb_name)
          sources = Aircana::Contexts::Manifest.sources_from_manifest(kb_name)
          sources.size
        rescue StandardError
          0
        end

        def kb_exists?(kb_name)
          kb_dir = File.join(Aircana.configuration.kb_knowledge_dir, kb_name)
          Dir.exist?(kb_dir)
        end

        def valid_url?(url)
          uri = URI.parse(url)
          %w[http https].include?(uri.scheme) && !uri.host.nil?
        rescue URI::InvalidURIError
          false
        end

        def all_kbs
          kb_dir = Aircana.configuration.kb_knowledge_dir
          return [] unless Dir.exist?(kb_dir)

          find_kb_folders(kb_dir)
        end

        # rubocop:disable Metrics/MethodLength
        def refresh_single_kb(kb_name)
          Aircana.human_logger.info "Refreshing KB '#{kb_name}'..."

          begin
            result = perform_manifest_aware_refresh(kb_name)
            regenerate_skill_md(kb_name)
            regenerate_agent_md(kb_name)
            {
              success: true,
              pages_count: result[:pages_count],
              sources: result[:sources]
            }
          rescue Aircana::Error => e
            Aircana.human_logger.error "Failed to refresh KB '#{kb_name}': #{e.message}"
            {
              success: false,
              pages_count: 0,
              sources: [],
              error: e.message
            }
          end
        end
        # rubocop:enable Metrics/MethodLength

        # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        def print_refresh_all_summary(results)
          Aircana.human_logger.info ""
          Aircana.human_logger.info "=== Refresh All Summary ==="
          Aircana.human_logger.success "✓ Successful: #{results[:successful]}/#{results[:total]} KBs"
          Aircana.human_logger.success "✓ Total pages refreshed: #{results[:total_pages]}"

          if results[:failed].positive?
            Aircana.human_logger.error "✗ Failed: #{results[:failed]} KBs"
            Aircana.human_logger.info ""
            Aircana.human_logger.info "Failed KBs:"
            results[:failed_kbs].each do |failed_kb|
              Aircana.human_logger.error "  - #{failed_kb[:name]}: #{failed_kb[:error]}"
            end
          end

          Aircana.human_logger.info ""
        end
        # rubocop:enable Metrics/MethodLength, Metrics/AbcSize
      end
    end
  end
end
