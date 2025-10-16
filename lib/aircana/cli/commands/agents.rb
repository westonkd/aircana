# frozen_string_literal: true

require "json"
require "tty-prompt"
require_relative "../../generators/agents_generator"
require_relative "../../contexts/manifest"
require_relative "../../contexts/web"

module Aircana
  module CLI
    module Agents # rubocop:disable Metrics/ModuleLength
      SUPPORTED_CLAUDE_MODELS = %w[sonnet haiku inherit].freeze
      SUPPORTED_CLAUDE_COLORS = %w[red blue green yellow purple orange pink cyan].freeze

      class << self # rubocop:disable Metrics/ClassLength
        def refresh(agent)
          normalized_agent = normalize_string(agent)

          # Check if this is a local knowledge base agent
          kb_type = Aircana::Contexts::Manifest.kb_type_from_manifest(normalized_agent)
          if kb_type == "local"
            Aircana.human_logger.info "⊘ Skipping #{normalized_agent} (local knowledge base - no refresh needed)"
            return
          end

          perform_manifest_aware_refresh(normalized_agent)
        rescue Aircana::Error => e
          handle_refresh_error(normalized_agent, e)
        end

        def create # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
          prompt = TTY::Prompt.new

          agent_name = prompt.ask("Agent name:")
          short_description = prompt.ask("Briefly describe what your agent does:")
          model = prompt.select("Select a model for your agent:", SUPPORTED_CLAUDE_MODELS)
          color = prompt.select("Select a color for your agent:", SUPPORTED_CLAUDE_COLORS)

          # Prompt for knowledge base type
          kb_type = prompt.select("Knowledge base type:", [
            { name: "Remote - Stored in ~/.claude/agents/, not version controlled, requires refresh", value: "remote" },
            { name: "Local - Stored in agents/<name>/knowledge/, version controlled, no refresh needed", value: "local" }
          ])

          description = description_from_claude(short_description)
          normalized_agent_name = normalize_string(agent_name)

          file = Generators::AgentsGenerator.new(
            agent_name: normalized_agent_name,
            description:,
            short_description:,
            model: normalize_string(model),
            color: normalize_string(color),
            kb_type:
          ).generate

          Aircana.human_logger.success "Agent created at #{file}"

          # Prompt for knowledge fetching
          prompt_for_knowledge_fetch(prompt, normalized_agent_name, kb_type)

          # Prompt for web URL fetching
          prompt_for_url_fetch(prompt, normalized_agent_name, kb_type)

          # Prompt for agent file review
          prompt_for_agent_review(prompt, file)

          Aircana.human_logger.success "Agent '#{agent_name}' setup complete!"
        end

        def list
          agent_dir = Aircana.configuration.agent_knowledge_dir
          return print_no_agents_message unless Dir.exist?(agent_dir)

          agent_folders = find_agent_folders(agent_dir)
          return print_no_agents_message if agent_folders.empty?

          print_agents_list(agent_folders)
        end

        def add_url(agent, url) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/PerceivedComplexity
          normalized_agent = normalize_string(agent)

          unless agent_exists?(normalized_agent)
            Aircana.human_logger.error "Agent '#{agent}' not found. Use 'aircana agents list' to see available agents."
            exit 1
          end

          # Get kb_type from manifest to know where to store
          kb_type = Aircana::Contexts::Manifest.kb_type_from_manifest(normalized_agent)

          web = Aircana::Contexts::Web.new
          result = web.fetch_url_for(agent: normalized_agent, url: url, kb_type: kb_type)

          if result
            # Update manifest with the new URL
            existing_sources = Aircana::Contexts::Manifest.sources_from_manifest(normalized_agent)
            web_sources = existing_sources.select { |s| s["type"] == "web" }
            other_sources = existing_sources.reject { |s| s["type"] == "web" }

            if web_sources.any?
              # Add to existing web source
              web_sources.first["urls"] << result
            else
              # Create new web source
              web_sources = [{ "type" => "web", "urls" => [result] }]
            end

            all_sources = other_sources + web_sources
            Aircana::Contexts::Manifest.update_manifest(normalized_agent, all_sources)

            Aircana.human_logger.success "Successfully added URL to agent '#{agent}'"
          else
            Aircana.human_logger.error "Failed to fetch URL: #{url}"
            exit 1
          end
        rescue Aircana::Error => e
          Aircana.human_logger.error "Failed to add URL: #{e.message}"
          exit 1
        end

        def refresh_all # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
          agent_names = all_agents

          if agent_names.empty?
            Aircana.human_logger.info "No agents found to refresh."
            return
          end

          Aircana.human_logger.info "Starting refresh for #{agent_names.size} agent(s)..."

          results = {
            total: agent_names.size,
            successful: 0,
            failed: 0,
            skipped: 0,
            total_pages: 0,
            failed_agents: [],
            skipped_agents: []
          }

          agent_names.each do |agent_name|
            # Check if this is a local knowledge base agent
            kb_type = Aircana::Contexts::Manifest.kb_type_from_manifest(agent_name)
            if kb_type == "local"
              Aircana.human_logger.info "⊘ Skipping #{agent_name} (local knowledge base)"
              results[:skipped] += 1
              results[:skipped_agents] << agent_name
              next
            end

            result = refresh_single_agent(agent_name)
            if result[:success]
              results[:successful] += 1
              results[:total_pages] += result[:pages_count]
            else
              results[:failed] += 1
              results[:failed_agents] << { name: agent_name, error: result[:error] }
            end
          end

          print_refresh_all_summary(results)
        end

        def migrate_to_local # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
          agent_names = all_agents

          if agent_names.empty?
            Aircana.human_logger.info "No agents found to migrate."
            return
          end

          # Filter to only remote agents
          remote_agents = agent_names.select do |agent_name|
            Aircana::Contexts::Manifest.kb_type_from_manifest(agent_name) == "remote"
          end

          if remote_agents.empty?
            Aircana.human_logger.info "No remote agents found. All agents are already using local knowledge bases."
            return
          end

          Aircana.human_logger.warn "⚠️  This will migrate #{remote_agents.size} agent(s) to local knowledge bases."
          Aircana.human_logger.warn "Knowledge will be version-controlled and stored in .claude/agents/<agent>/knowledge/"
          Aircana.human_logger.info ""

          results = {
            total: remote_agents.size,
            successful: 0,
            failed: 0,
            migrated_agents: [],
            failed_agents: []
          }

          remote_agents.each do |agent_name|
            result = migrate_single_agent(agent_name)
            if result[:success]
              results[:successful] += 1
              results[:migrated_agents] << agent_name
            else
              results[:failed] += 1
              results[:failed_agents] << { name: agent_name, error: result[:error] }
            end
          end

          print_migration_summary(results)
        end

        private

        def perform_refresh(normalized_agent, kb_type = "remote")
          confluence = Aircana::Contexts::Confluence.new
          result = confluence.fetch_pages_for(agent: normalized_agent, kb_type: kb_type)

          log_refresh_result(normalized_agent, result[:pages_count])
          result
        end

        def log_refresh_result(normalized_agent, pages_count)
          if pages_count.positive?
            Aircana.human_logger.success "Successfully refreshed #{pages_count} pages for agent '#{normalized_agent}'"
          else
            log_no_pages_found(normalized_agent)
          end
        end

        def perform_manifest_aware_refresh(normalized_agent) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
          total_pages = 0
          all_sources = []

          # Try manifest-based refresh first
          if Aircana::Contexts::Manifest.manifest_exists?(normalized_agent)
            Aircana.human_logger.info "Refreshing from knowledge manifest..."

            # Refresh Confluence sources
            confluence = Aircana::Contexts::Confluence.new
            confluence_result = confluence.refresh_from_manifest(agent: normalized_agent)
            total_pages += confluence_result[:pages_count]
            all_sources.concat(confluence_result[:sources])

            # Refresh web sources
            web = Aircana::Contexts::Web.new
            web_result = web.refresh_web_sources(agent: normalized_agent)
            total_pages += web_result[:pages_count]
            all_sources.concat(web_result[:sources])
          else
            Aircana.human_logger.info "No manifest found, falling back to label-based search..."
            confluence = Aircana::Contexts::Confluence.new
            confluence_result = confluence.fetch_pages_for(agent: normalized_agent)
            total_pages += confluence_result[:pages_count]
            all_sources.concat(confluence_result[:sources])
          end

          # Update manifest with all sources combined
          Aircana::Contexts::Manifest.update_manifest(normalized_agent, all_sources) if all_sources.any?

          log_refresh_result(normalized_agent, total_pages)
          { pages_count: total_pages, sources: all_sources }
        end

        def ensure_gitignore_entry(kb_type = "remote")
          # Only add to gitignore for remote knowledge bases
          return if kb_type == "local"

          gitignore_path = gitignore_file_path
          pattern = gitignore_pattern

          return if gitignore_has_pattern?(gitignore_path, pattern)

          append_to_gitignore(gitignore_path, pattern)
          Aircana.human_logger.success "Added knowledge directories to .gitignore"
        rescue StandardError => e
          Aircana.human_logger.warn "Could not update .gitignore: #{e.message}"
          Aircana.human_logger.info "Manually add: #{pattern}"
        end

        def gitignore_file_path
          File.join(Aircana.configuration.project_dir, ".gitignore")
        end

        def gitignore_pattern
          ".claude/agents/*/knowledge/"
        end

        def gitignore_has_pattern?(gitignore_path, pattern)
          return false unless File.exist?(gitignore_path)

          content = File.read(gitignore_path)
          if content.lines.any? { |line| line.strip == pattern }
            Aircana.human_logger.info "Knowledge directories already in .gitignore"
            true
          else
            false
          end
        end

        def append_to_gitignore(gitignore_path, pattern)
          existing_content = File.exist?(gitignore_path) ? File.read(gitignore_path) : ""
          content_to_append = existing_content.empty? || existing_content.end_with?("\n") ? "" : "\n"
          content_to_append += "#{pattern}\n"

          File.open(gitignore_path, "a") { |f| f.write(content_to_append) }
        end

        def log_no_pages_found(normalized_agent)
          Aircana.human_logger.info "No pages found for agent '#{normalized_agent}'. " \
                                    "Make sure pages are labeled with '#{normalized_agent}' in Confluence."
        end

        def handle_refresh_error(normalized_agent, error)
          Aircana.human_logger.error "Failed to refresh agent '#{normalized_agent}': #{error.message}"
          exit 1
        end

        def normalize_string(string)
          string.strip.downcase.gsub(" ", "-")
        end

        def description_from_claude(description)
          prompt = build_agent_description_prompt(description)
          claude_client = Aircana::LLM::ClaudeClient.new
          claude_client.prompt(prompt)
        end

        def build_agent_description_prompt(description)
          <<~PROMPT
            Create a concise Claude Code agent description file (without frontmatter)
            for an agent that is described as: #{description}.

            The agent should be specialized and focused on its domain knowledge.
            Include instructions that the agent should primarily rely on information
            from its knowledge base rather than general knowledge when answering questions
            within its domain.

            Print the output to STDOUT only, without any additional commentary.

            The description should be 2-3 sentences. Most of the agent's context comes from
            its knowledge base
          PROMPT
        end

        def prompt_for_knowledge_fetch(prompt, normalized_agent_name, kb_type) # rubocop:disable Metrics/MethodLength
          return unless confluence_configured?

          if prompt.yes?("Would you like to fetch knowledge for this agent from Confluence now?")
            Aircana.human_logger.info "Fetching knowledge from Confluence..."
            result = perform_refresh(normalized_agent_name, kb_type)
            ensure_gitignore_entry(kb_type) if result[:pages_count]&.positive?
          else
            refresh_message = kb_type == "local" ? "fetch knowledge" : "run 'aircana agents refresh #{normalized_agent_name}'"
            Aircana.human_logger.info(
              "Skipping knowledge fetch. You can #{refresh_message} later."
            )
          end
        rescue Aircana::Error => e
          Aircana.human_logger.warn "Failed to fetch knowledge: #{e.message}"
          refresh_message = kb_type == "local" ? "fetch knowledge" : "try again later with 'aircana agents refresh #{normalized_agent_name}'"
          Aircana.human_logger.info "You can #{refresh_message}"
        end

        def prompt_for_url_fetch(prompt, normalized_agent_name, kb_type) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
          return unless prompt.yes?("Would you like to add web URLs for this agent's knowledge base?")

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

          return if urls.empty?

          begin
            Aircana.human_logger.info "Fetching #{urls.size} URL(s)..."
            web = Aircana::Contexts::Web.new
            result = web.fetch_urls_for(agent: normalized_agent_name, urls: urls, kb_type: kb_type)

            if result[:pages_count].positive?
              Aircana.human_logger.success "Successfully fetched #{result[:pages_count]} URL(s)"
              ensure_gitignore_entry(kb_type)
            else
              Aircana.human_logger.warn "No URLs were successfully fetched"
            end
          rescue Aircana::Error => e
            Aircana.human_logger.warn "Failed to fetch URLs: #{e.message}"
            Aircana.human_logger.info(
              "You can add URLs later with 'aircana agents add-url #{normalized_agent_name} <URL>'"
            )
          end
        end

        def prompt_for_agent_review(prompt, file_path)
          Aircana.human_logger.info "Agent file created at: #{file_path}"

          return unless prompt.yes?("Would you like to review and edit the agent file?")

          open_file_in_editor(file_path)
        end

        def confluence_configured? # rubocop:disable Metrics/AbcSize
          config = Aircana.configuration

          base_url_present = !config.confluence_base_url.nil? && !config.confluence_base_url.empty?
          username_present = !config.confluence_username.nil? && !config.confluence_username.empty?
          token_present = !config.confluence_api_token.nil? && !config.confluence_api_token.empty?

          base_url_present && username_present && token_present
        end

        def open_file_in_editor(file_path)
          editor = ENV["EDITOR"] || find_available_editor

          if editor
            Aircana.human_logger.info "Opening #{file_path} in #{editor}..."
            system("#{editor} '#{file_path}'")
          else
            Aircana.human_logger.warn "No editor found. Please edit #{file_path} manually."
          end
        end

        def print_no_agents_message
          Aircana.human_logger.info("No agents configured yet.")
        end

        def find_agent_folders(agent_dir)
          Dir.entries(agent_dir).select do |entry|
            path = File.join(agent_dir, entry)
            File.directory?(path) && !entry.start_with?(".")
          end
        end

        def print_agents_list(agent_folders)
          Aircana.human_logger.info("Configured agents:")
          agent_folders.each_with_index do |agent_name, index|
            description = get_agent_description(agent_name)
            Aircana.human_logger.info("  #{index + 1}. #{agent_name} - #{description}")
          end
          Aircana.human_logger.info("\nTotal: #{agent_folders.length} agents")
        end

        def get_agent_description(agent_name)
          agent_config_path = File.join(
            Aircana.configuration.agent_knowledge_dir,
            agent_name,
            "agent.json"
          )
          return "Configuration incomplete" unless File.exist?(agent_config_path)

          config = JSON.parse(File.read(agent_config_path))
          config["description"] || "No description available"
        end

        def agent_exists?(agent_name)
          agent_dir = File.join(Aircana.configuration.agent_knowledge_dir, agent_name)
          Dir.exist?(agent_dir)
        end

        def valid_url?(url)
          uri = URI.parse(url)
          %w[http https].include?(uri.scheme) && !uri.host.nil?
        rescue URI::InvalidURIError
          false
        end

        def find_available_editor
          %w[code subl atom nano vim vi].find { |cmd| system("which #{cmd} > /dev/null 2>&1") }
        end

        def all_agents
          agent_dir = Aircana.configuration.agent_knowledge_dir
          return [] unless Dir.exist?(agent_dir)

          find_agent_folders(agent_dir)
        end

        def refresh_single_agent(agent_name) # rubocop:disable Metrics/MethodLength
          Aircana.human_logger.info "Refreshing agent '#{agent_name}'..."

          begin
            result = perform_manifest_aware_refresh(agent_name)
            {
              success: true,
              pages_count: result[:pages_count],
              sources: result[:sources]
            }
          rescue Aircana::Error => e
            Aircana.human_logger.error "Failed to refresh agent '#{agent_name}': #{e.message}"
            {
              success: false,
              pages_count: 0,
              sources: [],
              error: e.message
            }
          end
        end

        def print_refresh_all_summary(results) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
          Aircana.human_logger.info ""
          Aircana.human_logger.info "=== Refresh All Summary ==="
          Aircana.human_logger.success "✓ Successful: #{results[:successful]}/#{results[:total]} agents"
          Aircana.human_logger.success "✓ Total pages refreshed: #{results[:total_pages]}"

          if results[:skipped].positive?
            Aircana.human_logger.info "⊘ Skipped: #{results[:skipped]} agent(s) (local knowledge base)"
          end

          if results[:failed].positive?
            Aircana.human_logger.error "✗ Failed: #{results[:failed]} agents"
            Aircana.human_logger.info ""
            Aircana.human_logger.info "Failed agents:"
            results[:failed_agents].each do |failed_agent|
              Aircana.human_logger.error "  - #{failed_agent[:name]}: #{failed_agent[:error]}"
            end
          end

          Aircana.human_logger.info ""
        end

        def migrate_single_agent(agent_name) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
          Aircana.human_logger.info "Migrating agent '#{agent_name}'..."

          begin
            # Step 1: Refresh knowledge from sources to ensure we have latest
            Aircana.human_logger.info "  Refreshing knowledge from sources..."
            perform_manifest_aware_refresh(agent_name)

            # Step 2: Copy knowledge files from global to local directory
            Aircana.human_logger.info "  Copying knowledge files to local directory..."
            copy_knowledge_files(agent_name)

            # Step 3: Update manifest kb_type to "local"
            Aircana.human_logger.info "  Updating manifest..."
            sources = Aircana::Contexts::Manifest.sources_from_manifest(agent_name)
            Aircana::Contexts::Manifest.update_manifest(agent_name, sources, kb_type: "local")

            # Step 4: Regenerate agent file with new kb_type
            Aircana.human_logger.info "  Regenerating agent file..."
            regenerate_agent_file(agent_name)

            Aircana.human_logger.success "✓ Successfully migrated '#{agent_name}'"
            { success: true }
          rescue StandardError => e
            Aircana.human_logger.error "✗ Failed to migrate agent '#{agent_name}': #{e.message}"
            { success: false, error: e.message }
          end
        end

        def copy_knowledge_files(agent_name)
          config = Aircana.configuration
          source_dir = config.global_agent_knowledge_path(agent_name)
          dest_dir = config.local_agent_knowledge_path(agent_name)

          unless Dir.exist?(source_dir)
            Aircana.human_logger.warn "    No knowledge files found at #{source_dir}"
            return
          end

          FileUtils.mkdir_p(dest_dir)

          # Copy all markdown files
          Dir.glob(File.join(source_dir, "*.md")).each do |file|
            filename = File.basename(file)
            dest_file = File.join(dest_dir, filename)
            FileUtils.cp(file, dest_file)
            Aircana.human_logger.info "    Copied #{filename}"
          end
        end

        def regenerate_agent_file(agent_name)
          # Read existing agent file to get metadata
          agent_file_path = File.join(Aircana.configuration.agents_dir, "#{agent_name}.md")
          unless File.exist?(agent_file_path)
            Aircana.human_logger.warn "    Agent file not found at #{agent_file_path}, skipping regeneration"
            return
          end

          # Parse frontmatter to get agent metadata
          content = File.read(agent_file_path)
          frontmatter_match = content.match(/^---\n(.*?)\n---\n(.*)$/m)
          return unless frontmatter_match

          frontmatter = frontmatter_match[1]
          description = frontmatter_match[2]

          # Parse YAML-like frontmatter
          metadata = {}
          frontmatter.lines.each do |line|
            key, value = line.strip.split(":", 2)
            metadata[key.strip] = value&.strip
          end

          # Generate new agent file with kb_type="local"
          Generators::AgentsGenerator.new(
            agent_name: agent_name,
            description: description,
            short_description: metadata["description"],
            model: metadata["model"],
            color: metadata["color"],
            kb_type: "local"
          ).generate
        end

        def print_migration_summary(results) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
          Aircana.human_logger.info ""
          Aircana.human_logger.info "=== Migration Summary ==="
          Aircana.human_logger.success "✓ Successfully migrated: #{results[:successful]}/#{results[:total]} agents"

          if results[:successful].positive?
            Aircana.human_logger.info ""
            Aircana.human_logger.info "Migrated agents:"
            results[:migrated_agents].each do |agent_name|
              Aircana.human_logger.success "  ✓ #{agent_name}"
            end
          end

          if results[:failed].positive?
            Aircana.human_logger.error "✗ Failed: #{results[:failed]} agents"
            Aircana.human_logger.info ""
            Aircana.human_logger.info "Failed agents:"
            results[:failed_agents].each do |failed_agent|
              Aircana.human_logger.error "  - #{failed_agent[:name]}: #{failed_agent[:error]}"
            end
          end

          if results[:successful].positive?
            Aircana.human_logger.info ""
            Aircana.human_logger.warn "⚠️  Knowledge is now version-controlled in .claude/agents/<agent>/knowledge/"
            Aircana.human_logger.info "Review and commit these changes to your repository."
          end

          Aircana.human_logger.info ""
        end
      end
    end
  end
end
