# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Development
- `bundle exec exe/aircana <command>` - Run commands in development mode
- `bundle install` - Install dependencies
- `bin/setup` - Set up development environment
- `bin/console` - Interactive prompt for experimentation

### Testing and Quality
- `rake spec` or `bundle exec rspec` - Run all tests
- `bundle exec rspec spec/aircana/cli/commands/kb_spec.rb` - Run specific test file
- `bundle exec rspec spec/aircana/cli/commands/kb_spec.rb:15` - Run test at specific line
- `bundle exec rspec --format documentation` - Run tests with detailed output
- `bundle exec rubocop` - Run linter
- `bundle exec rubocop -a` - Run linter with auto-fix
- `rake` - Run both tests and linter (default task)

### Gem Management
- `bundle exec rake build` - Build gem package
- `bundle exec rake install` - Install gem locally
- `bundle exec rake release` - Release new version (updates version, creates git tag, pushes to rubygems)

### Aircana CLI Commands

**Plugin Management:**
- `aircana init [DIRECTORY]` - Initialize a Claude Code plugin in specified directory (defaults to current)
- `aircana init --plugin-name NAME` - Initialize with custom plugin name
- `aircana plugin info` - Display plugin information
- `aircana plugin update` - Update plugin metadata interactively
- `aircana plugin version` - Show current version
- `aircana plugin version bump [major|minor|patch]` - Bump semantic version
- `aircana plugin version set` - Set specific version
- `aircana plugin validate` - Validate plugin structure and manifests

**Knowledge Base Management:**
- `aircana kb create` - Create a new knowledge base interactively
- `aircana kb list` - List all configured knowledge bases
- `aircana kb refresh <kb-name>` - Refresh knowledge base from Confluence and web sources
- `aircana kb refresh-all` - Refresh knowledge for all configured knowledge bases
- `aircana kb add-url <kb-name> <url>` - Add a web URL to a knowledge base

**Hooks:**
- Hooks are automatically generated during `aircana init`
- Default hooks include: `session_start`, `refresh_skills`, and `notification_sqs`
- `refresh_skills` automatically refreshes remote knowledge bases once per 24 hours
- Hook scripts are stored in `scripts/` directory
- Hook configuration is managed via `hooks/hooks.json`

**System:**
- `aircana doctor` - Check system health and dependencies
- `aircana doctor --verbose` - Show detailed dependency information
- `aircana generate` - Generate plugin components from templates
- `aircana dump-context <kb-name>` - Dump context for specified knowledge base

## Architecture

### Core Structure
Aircana is a Ruby gem that creates and manages Claude Code plugins with knowledge bases. The main components:

- **CLI Layer** (`lib/aircana/cli/`): Thor-based command line interface with subcommands
  - `app.rb`: Main Thor application defining all commands and subcommands
  - `subcommand.rb`: Base class for subcommands (kb, plugin)
  - `shell_command.rb`: Shell command execution utilities
  - `commands/`: Individual command implementations
    - `init.rb`: Plugin initialization
    - `plugin.rb`: Plugin metadata management
    - `kb.rb`: Knowledge base CRUD operations
    - `doctor.rb`: System health checks with modular check system
    - `generate.rb`: Generates plugin components from templates
    - `dump_context.rb`: Outputs knowledge base content for debugging

- **Plugin Management**:
  - `plugin_manifest.rb`: Manages `.claude-plugin/plugin.json` with validation
  - `hooks_manifest.rb`: Manages `hooks/hooks.json` with event validation

- **Contexts** (`lib/aircana/contexts/`): Knowledge source management
  - `confluence.rb`: Main class composed of modules for separation of concerns:
    - `ConfluenceLogging`: Request/response logging
    - `ConfluenceHttp`: HTTParty integration and API calls
    - `ConfluenceContent`: Content processing and storage
    - `ConfluenceSetup`: Configuration validation
  - `web.rb`: Web URL fetching with:
    - HTML to Markdown conversion (ReverseMarkdown)
    - Main content extraction (removes nav, ads, scripts)
    - Claude API integration for generating meaningful page titles
  - `manifest.rb`: Per-knowledge-base manifest system tracking:
    - Knowledge sources (Confluence, web)
    - Source metadata (page IDs, URLs, timestamps)
    - KB type (local or remote)
    - Manifest format version (1.0)
  - `local.rb`: File system operations for storing knowledge

- **Generators** (`lib/aircana/generators/`): ERB-based template generation
  - `base_generator.rb`: Base class with ERB rendering and file writing
  - `skills_generator.rb`: Knowledge base file generation (Markdown format)
  - Command generators: plan, execute, record, review, apply_feedback, ask_expert
  - `hooks_generator.rb`: Hook script generation
  - Templates location: `lib/aircana/templates/`

- **Configuration** (`lib/aircana/configuration.rb`): Path resolution system
  - Plugin root detection via environment variables (AIRCANA_PLUGIN_ROOT, CLAUDE_PLUGIN_ROOT)
  - Plugin-aware paths (commands, skills, hooks directories)
  - Global vs plugin-local knowledge storage
  - Automatic plugin name extraction from plugin.json
  - Resolves to `~/.claude/skills/<kb-name>/` for knowledge storage

- **LLM Integration**:
  - `llm/claude_client.rb`: Claude API client for web title generation

- **Support Classes**:
  - `human_logger.rb`: User-friendly, non-technical logging output
  - `progress_tracker.rb`: Batch operations and spinner utilities
  - `system_checker.rb`: Dependency validation (fzf required, bat/fd optional)
  - `fzf_helper.rb`: Interactive fuzzy selection

### Key Concepts
- **Plugins**: Distributable Claude Code extensions with manifests, skills/knowledge bases, commands, and hooks
- **Plugin Manifests**: JSON files defining plugin metadata (`.claude-plugin/plugin.json`)
- **Knowledge Bases (Skills)**: Curated documentation from Confluence and web sources that provide domain expertise
- **Manifests**: Per-knowledge-base JSON tracking sources, metadata, and KB type (local/remote)
- **Hooks**: Event-driven automation through `hooks/hooks.json`
- **Commands**: Custom slash commands for workflow automation

### File Organization
- **Plugin Structure**:
  - `.claude-plugin/plugin.json` - Plugin manifest with metadata and versioning
  - `agents/` - Knowledge base markdown files (skill definitions)
  - `agents/<kb-name>/manifest.json` - Tracks knowledge sources per KB
  - `agents/<kb-name>/knowledge/` - Local knowledge base content (if KB type is "local")
  - `commands/` - Slash command markdown files
  - `hooks/` - hooks.json manifest defining hook configurations
  - `scripts/` - Hook scripts and utility scripts

- **Global Configuration**:
  - `~/.aircana/` - Global Aircana configuration directory
  - `~/.aircana/aircana.out/` - Generated templates output directory
  - `~/.claude/skills/` - Runtime knowledge base storage

- **Knowledge Storage Architecture**:
  - **Remote KBs (not version controlled)**: `~/.claude/skills/<kb-name>/`
    - Actual knowledge base content (Markdown files)
    - Refreshed via `aircana kb refresh`
    - Excluded from version control to avoid bloat/sensitivity
  - **Local KBs (version controlled)**: `agents/<kb-name>/knowledge/`
    - Version-controlled knowledge content in plugin repository
    - Auto-synced to `~/.claude/skills/<kb-name>/` via SessionStart hook
    - Teams can collaborate on knowledge directly in Git
  - **Plugin-local manifests (version controlled)**: `agents/<kb-name>/manifest.json`
    - Tracks knowledge sources (Confluence labels, web URLs)
    - Specifies KB type ("local" or "remote")
    - Team members can refresh knowledge independently
    - Format:
      ```json
      {
        "version": "1.0",
        "kb_name": "my-kb",
        "kb_type": "remote",
        "sources": [
          {
            "type": "confluence",
            "label": "my-kb",
            "pages": [{"id": "123456"}]
          },
          {
            "type": "web",
            "urls": [{"url": "https://example.com"}]
          }
        ]
      }
      ```

- **Path Resolution**:
  - Environment variables override defaults:
    - `AIRCANA_PLUGIN_ROOT` or `CLAUDE_PLUGIN_ROOT`: Override plugin root directory
  - Configuration class resolves paths dynamically based on plugin.json presence

### Dependencies
- Thor (~> 0.19.1) for CLI framework
- tty-prompt (~> 0.23.1) for interactive prompts
- tty-progressbar (~> 0.18) for progress indicators
- tty-spinner (~> 0.9) for loading spinners
- HTTParty (~> 0.21) for HTTP requests
- ReverseMarkdown (~> 2.1) for HTML to Markdown conversion
- Ruby >= 3.3.0 required
- External tools:
  - git (required)
  - fzf (required) - used for interactive selection
  - bat (optional) - enhanced file viewing
  - fd (optional) - faster file finding
  - aws-cli (optional) - for SQS notifications integration

### Key Implementation Patterns

**Module-Based Composition**:
The Confluence class demonstrates module-based composition for separation of concerns:
```ruby
class Confluence
  include ConfluenceLogging    # Request/response logging
  include ConfluenceHttp       # HTTParty integration
  include ConfluenceContent    # Content processing
  include ConfluenceSetup      # Configuration validation
end
```
This pattern keeps each module focused on a single responsibility while composing full functionality.

**ERB Template Generation**:
All plugin components are generated from ERB templates in `lib/aircana/templates/`:
- `skills/` - Knowledge base templates (skill.md.erb)
- `commands/` - Slash command templates
- `hooks/` - Hook script templates

Generators inherit from `BaseGenerator` which handles:
- ERB rendering with `locals` hash
- File system operations
- Output directory preparation

**Progress Tracking**:
User-facing operations use `ProgressTracker` for consistent UX:
```ruby
ProgressTracker.with_spinner("Searching pages") do
  # Long-running operation
end

ProgressTracker.with_batch_progress(items, "Processing") do |item, index|
  # Process each item
end
```

**Manifest-Based Knowledge Tracking**:
Each knowledge base has a `manifest.json` that tracks knowledge sources:
- Version controlled: `agents/<kb-name>/manifest.json` (sources metadata, KB type)
- Remote KBs: Content stored in `~/.claude/skills/<kb-name>/` (not version controlled)
- Local KBs: Content stored in `agents/<kb-name>/knowledge/` (version controlled), synced to `~/.claude/skills/`
- Team members run `aircana kb refresh` to sync remote knowledge locally

**Plugin-Aware Path Resolution**:
Configuration class detects plugin mode and resolves paths accordingly:
- Checks for `.claude-plugin/plugin.json` presence
- Respects environment variable overrides (AIRCANA_PLUGIN_ROOT)
- Extracts plugin name from plugin.json for prefixing knowledge paths

### Testing
- Uses RSpec for testing with specs in `spec/` directory
- Test files follow naming convention: `spec/<path>/<file>_spec.rb`
- Rubocop configured with custom rules in `.rubocop.yml`
- String style enforced as double quotes
- Run specific test: `bundle exec rspec spec/path/to/file_spec.rb:15`

### Knowledge Sources
Knowledge bases can sync content from multiple sources:

**Confluence Integration:**
- Environment variables: `CONFLUENCE_BASE_URL`, `CONFLUENCE_USERNAME`, `CONFLUENCE_API_TOKEN`
- Pages fetched via Confluence REST API v2 using HTTParty
- Label-based discovery: searches for pages labeled with KB name under "global" prefix
- Pagination support for large result sets
- HTML content converted to Markdown via ReverseMarkdown
- Page metadata (ID) tracked in manifest for refresh operations

**Web URL Integration:**
- Accepts any HTTP/HTTPS URL
- HTML content extraction with smart filtering:
  - Removes navigation, headers, footers, ads, scripts
  - Targets main content areas (main, article, .content selectors)
  - Converts to clean Markdown
- Automatic title generation:
  - Extracts HTML `<title>` tag
  - Falls back to Claude API for meaningful titles if HTML title is generic/truncated
  - Uses URL path as final fallback
- URL metadata tracked in manifest

**Unified Management:**
- Both source types tracked in manifest.json per knowledge base
- Manifest schema version 1.0
- `aircana kb refresh <kb-name>` refreshes all sources (Confluence + web) for remote KBs
- `aircana kb refresh-all` refreshes all configured remote knowledge bases
- Remote KB content stored as Markdown in `~/.claude/skills/<kb-name>/`
- Local KB content stored in `agents/<kb-name>/knowledge/`, synced to `~/.claude/skills/<kb-name>/`
- Knowledge paths referenced in skill files use tilde notation: `~/.claude/skills/.../`