# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [5.2.5]

### Fixed
- Hardened Confluence macro processing to prevent content truncation
  - Added negative lookahead to fallback structured macro regex to exclude code macros
  - Prevents edge case where unmatched code blocks could consume content up to a later info/note macro
  - Defense in depth fix complementing the whitespace handling in 5.2.4

## [5.2.4]

### Fixed
- Fixed Confluence code blocks with whitespace around CDATA not being parsed
  - Confluence API often returns newlines/spaces between `<ac:plain-text-body>` and `<![CDATA[`
  - Added `\s*` to regex to allow optional whitespace around CDATA sections
  - Previously, unmatched code blocks were stripped by generic `ac:` tag removal, truncating content

## [5.2.2]

### Fixed
- Fixed Confluence code blocks not being converted to markdown
  - Code blocks using `<ac:structured-macro ac:name="code">` with CDATA content were being stripped
  - Added preprocessing to convert Confluence code macros to `<pre><code>` tags before markdown conversion
  - Supports optional language parameter for syntax highlighting
  - Handles multiline code content and extra Confluence parameters (breakoutMode, breakoutWidth)

## [5.2.0]

### Added
- Knowledge base name prefix in generated summaries
  - All summaries now prefixed with `[kb-name]: ` to clarify scope
  - Format: `"[canvas-database-migrations]: Learn about database migrations and schema changes"`
  - Applies to both Confluence and web URL sources
  - Helps clients understand which knowledge base each summary belongs to
  - Fallback summaries also include the prefix when LLM generation fails

## [5.1.1]

### Fixed
- Fixed agent color changing randomly on KB refresh
  - Colors are now persisted in manifest.json
  - On first refresh after upgrade, the generated color is stored in the manifest
  - Subsequent refreshes read the color from manifest, ensuring consistency
  - Added `color` field to manifest schema (backward compatible)
  - Added `color_from_manifest()` helper method to Manifest class

## [5.1.0]

### Added
- Configurable LLM provider for summary/title generation
  - New environment variable `AIRCANA_LLM_PROVIDER` to switch between providers
  - Supports `claude` (default) and `bedrock` providers
  - Claude provider uses Claude Code CLI for LLM calls
  - Bedrock provider uses AWS Bedrock Runtime API with configurable region and model
- AWS Bedrock integration as alternative LLM provider
  - New environment variables: `AIRCANA_BEDROCK_REGION` (default: `us-east-1`), `AIRCANA_BEDROCK_MODEL` (default: `anthropic.claude-3-haiku-20240307-v1:0`)
  - Uses standard AWS credential chain for authentication
  - Added `aws-sdk-bedrockruntime` as a bundled dependency
- New `Aircana::LLM` module with factory pattern
  - `Aircana::LLM.client` returns configured provider instance
  - Base class with shared functionality (spinner, content truncation)
  - Unknown providers fall back to Claude with warning

### Changed
- Refactored `ClaudeClient` to inherit from new `LLM::Base` class
- Web and Confluence contexts now use `Aircana::LLM.client` factory instead of direct `ClaudeClient` instantiation

## [5.0.0]

### Removed
- **BREAKING**: Removed remote knowledge base type entirely
  - All knowledge bases are now version controlled in `skills/<kb-name>/`
  - Removed `kb_type` field from manifests (existing manifests with `kb_type` are still readable)
  - Removed KB type selection prompt during `aircana kb create`
  - Removed `refresh_skills` hook template and auto-installation
  - Removed automatic `.gitignore` management for remote KBs
  - Removed `kb_type_from_manifest` method from Manifest class
  - Removed `ensure_remote_knowledge_refresh_hook` functionality

### Changed
- `aircana kb refresh-all` description updated from "Refresh all remote knowledge bases" to "Refresh all knowledge bases"
- `aircana kb list` no longer displays KB type (shows only source count)
- Simplified KB workflow: create KB, fetch content, version control everything

### Migration Guide
To upgrade from version 4.x:
1. Existing knowledge bases will continue to work - the `kb_type` field is simply ignored
2. Remote KBs are no longer auto-refreshed on session start - run `aircana kb refresh <kb-name>` manually when needed
3. All KB content in `skills/<kb-name>/` should now be committed to version control
4. Remove any `refresh_skills` hook entries from `hooks/hooks.json` if present

## [4.4.0]

### Changed
- Knowledge base refresh commands now work for both local and remote KBs
  - `aircana kb refresh <kb-name>` and `aircana kb refresh-all` now refresh local KBs
  - Local KBs can have Confluence/web sources that need periodic refreshing
  - Confluence sources now store the label used during creation for discovering new pages
  - Refresh operation searches by label to find all pages, including newly added ones
  - The distinction between "local" and "remote" is about git version control, not refresh capability

## [4.3.0] - 2025-11-10

### Fixed
- Fixed ERB template syntax errors in command generators
  - Resolved nested string interpolation issues in `plan.erb` and `ask_expert.erb` templates
  - Templates were using complex nested `#{...}` interpolation incompatible with Ruby parser
  - Restructured templates to use ERB variables and string concatenation
  - Fixes "unexpected backslash" and "unterminated string" syntax errors during `aircana init`
  - All 187 tests passing

## [4.2.0] - 2025-10-31

### Changed
- **BREAKING**: `/ask-expert` command now uses Skills instead of agents
  - Uses Skill tool for faster knowledge access with shared context
  - Skills are named like "Learn Backend API", "Learn Database Design"
  - Better for quick Q&A scenarios
- `/plan` command continues using agents with Task tool
  - Maintains separate contexts per agent for better planning isolation
  - Uses Task tool with subagent_type parameter

## [4.1.0] - 2025-10-31

### Removed
- **BREAKING**: Removed obsolete slash commands: `/execute`, `/record`, `/review`, `/apply-feedback`
  - Only `/plan` and `/ask-expert` commands remain
  - `/plan` command simplified to focus on strategic planning with expert consultation
  - Workflow commands removed as they were incompatible with new subagent → skill architecture
- Removed Jira MCP tool integration from `doctor` command
  - Jira integration only used by removed workflow commands
  - Simplified doctor health checks

### Changed
- Updated `doctor` command terminology from "agents" to "knowledge bases" (KBs)
- Updated command generators to only include `plan` and `ask-expert`
- `/plan` command now requires user to be in Claude Code planning mode
- `/plan` command uses coordinator pattern to identify and consult relevant expert agents

### Documentation
- Updated README.md to remove obsolete workflow documentation
- Updated CLAUDE.md with current command generator list
- Added new "Slash Commands" section documenting `/ask-expert` and `/plan`

## [4.0.0] - 2025-10-31

### Changed
- **BREAKING**: Renamed "agents" to "knowledge bases" (KBs) throughout the system
  - Command renamed: `aircana agents` → `aircana kb`
  - Terminology updated to reflect purpose: curated domain knowledge for Claude Code
  - All commands now use KB terminology: `create`, `refresh`, `list`, `add-url`, `refresh-all`

### Added
- Comprehensive Confluence macro preprocessing for better content extraction
  - Converts panel macros to blockquotes
  - Converts info/note/warning macros to formatted blockquotes with emoji indicators
  - Strips Confluence-specific XML tags while preserving content
  - Fixes missing code examples from knowledge bases

### Fixed
- Knowledge base creation UX improvements
  - Better prompts that guide users naturally toward topic naming
  - Prevents duplicate "Learn" prefix in generated skill names
- SKILL.md generation now happens after content is fetched
  - Empty knowledge base warnings added
  - Proper file references in SKILL.md
- Filename strategy improvements
  - Matches disk files to manifest summaries
  - Correct file references in generated skills

### Removed
- Agent-specific terminology and templates
- Unused agent management commands and hooks

## [4.0.0.rc2] - 2025-10-17

### Fixed
- **KB Creation UX**: Improved knowledge base name prompt to guide users naturally
  - Changed prompt from "Knowledge base name:" to "What topic should this knowledge base cover?"
  - Added example default: "e.g., 'Canvas Backend Database', 'API Design'"
  - Prevents duplicate "Learn" prefix in generated skill names
- **SKILL.md Generation**: Fixed empty knowledge file references in SKILL.md
  - Reordered operations to generate SKILL.md after content is fetched
  - Modified prompt functions to return success status
  - SKILL.md now only generated as fallback if no content fetched
- **Confluence Content Processing**: Added comprehensive Confluence macro preprocessing
  - Removes empty code blocks from Confluence API responses
  - Converts panel macros to blockquotes
  - Converts info/note/warning macros to formatted blockquotes with emoji indicators
  - Strips all Confluence-specific XML tags while preserving content
  - Fixes bug where code examples were missing from knowledge base
- **Filename Strategy**: Fixed mismatch between stored filenames and manifest references
  - Primary method now scans actual markdown files on disk
  - Matches disk files to manifest summaries
  - Fallback extracts from manifest metadata for tests/initial generation
  - SKILL.md now correctly references existing knowledge files
- **Empty Knowledge Base Warning**: Added helpful warning when generating SKILL.md with no content
  - Warns user that SKILL.md will be empty
  - Suggests running `aircana kb refresh <kb-name>` to fetch knowledge

### Technical
- All tests passing (206 examples, 0 failures)
- Rubocop clean with justified disable directives for regex line lengths
- Backward compatible with existing tests and behavior

## [4.0.0.rc1] - 2025-10-17

### Changed
- **BREAKING**: Renamed "agents" command to "kb" (knowledge base) management
  - `aircana agents` → `aircana kb`
  - Commands: `create`, `refresh`, `list`, `add-url`, `refresh-all`
  - Updated CLI help menu to show "Knowledge Base Management" section
  - Internal refactoring: `AgentsGenerator` → `SkillsGenerator`
  - Template changes: `agents/` templates → `skills/` templates

### Removed
- Removed agent-specific hook templates (refresh_agents, sync_local_knowledge)
- Removed default agent templates (planner, executor, reviewer, apply_feedback, jira, sub-agent-coordinator)
- Cleaned up unused agent management files

### Migration Guide
To upgrade from version 3.x:
1. Replace all `aircana agents` commands with `aircana kb`:
   - `aircana agents create` → `aircana kb create`
   - `aircana agents refresh my-agent` → `aircana kb refresh my-agent`
   - `aircana agents refresh-all` → `aircana kb refresh-all`
   - `aircana agents add-url my-agent URL` → `aircana kb add-url my-agent URL`
   - `aircana agents list` → `aircana kb list`

## [3.2.1] - 2025-01-16

### Fixed
- SessionStart hook command now uses `${CLAUDE_PLUGIN_ROOT}` environment variable for proper path resolution
  - Changed from relative path `./scripts/sync_local_knowledge.sh` to `${CLAUDE_PLUGIN_ROOT}/scripts/sync_local_knowledge.sh`
  - Fixes "No such file or directory" error when hook executes

## [3.2.0] - 2025-01-16

### Added
- SessionStart hook automatically syncs local knowledge bases to `~/.claude/agents/` on session start
  - Compatible with macOS and Linux
  - Only syncs agents with `kb_type: "local"` in manifest
  - Uses rsync when available, falls back to cp
  - Logs sync operations to `~/.aircana/hooks.log`
- Smart .gitignore management
  - Remote agents: Adds `.claude/agents/*/knowledge/` to .gitignore
  - Local agents: Adds `!agents/*/knowledge/` negation to ensure version control

### Changed
- Local knowledge bases now stored in version-controlled `agents/<name>/knowledge/` directory
- Local knowledge auto-synced to `~/.claude/agents/<plugin>-<agent>/knowledge/` via SessionStart hook
- Both local and remote agents use consistent runtime path: `~/.claude/agents/<plugin>-<agent>/knowledge/`
- Updated CLI prompts to accurately describe sync behavior for local agents
- Migration warnings updated to reflect new local knowledge sync architecture

### Fixed
- Local and remote agents now use consistent runtime path in agent file definitions

## [3.1.0] - 2025-01-16

### Added
- Optional local knowledge base storage for agents
  - New `kb_type` field in agent manifests ("remote" or "local")
  - Local knowledge bases version-controlled in `agents/<name>/knowledge/` directory
  - Auto-synced to `~/.claude/agents/<plugin>-<agent>/knowledge/` via SessionStart hook
  - Remote knowledge bases fetched from Confluence/web to `~/.claude/agents/` (not version controlled)
  - Agent creation wizard prompts for knowledge base type with explanation
  - Refresh commands automatically skip local knowledge base agents
  - Existing agents without `kb_type` field default to "remote" for backward compatibility
- SessionStart hook automatically syncs local knowledge bases to `~/.claude/agents/` on session start
  - Compatible with macOS and Linux
  - Only syncs agents with `kb_type: "local"` in manifest
  - Uses rsync when available, falls back to cp
  - Logs sync operations to `~/.aircana/hooks.log`
- Migration command: `aircana agents migrate-to-local`
  - Migrates remote knowledge bases to local (version-controlled) storage
  - Automatically refreshes knowledge from sources before migration
  - Copies knowledge files from global to local directory
  - Updates manifests and regenerates agent files with correct paths
  - Provides detailed migration summary
- Smart .gitignore management
  - Remote agents: Adds `.claude/agents/*/knowledge/` to .gitignore
  - Local agents: Adds `!agents/*/knowledge/` negation to ensure version control

### Fixed
- Local and remote agents now use consistent runtime path: `~/.claude/agents/<plugin>-<agent>/knowledge/`
- Rubocop linting violations
  - Fixed line length issues with string concatenation
  - Added appropriate Metrics exclusions for complex CLI command methods
  - Removed redundant cop disable directives

## [3.0.0] - 2025-10-12

### Added
- Directory parameter support for `init` command
  - Can now specify target directory: `aircana init /path/to/project`
  - Automatically creates directory if it doesn't exist
  - Defaults to current directory when no path specified
- Plugin manifest system (`.claude-plugin/plugin.json`) for distributable Claude Code plugins
- Plugin management commands: `plugin info`, `plugin update`, `plugin version`, `plugin validate`
- Agent manifest system tracking knowledge sources (Confluence, web URLs)
- Web URL knowledge source support: `agents add-url` command to add public documentation
- Automatic daily knowledge refresh via SessionStart hook
- Development workflow commands: `/plan`, `/record`, `/execute`, `/review`, `/apply-feedback`
- Multiple specialized default agents: planner, executor, reviewer, apply_feedback, jira, sub-agent-coordinator
- Hook management: `hooks list`, `hooks enable`, `hooks disable`, `hooks create`, `hooks status`
- SQS notification integration for Slack/Teams alerts

### Changed
- **BREAKING**: Renamed `aircana install` command to `aircana init`
  - More intuitive naming aligned with standard CLI conventions
  - All documentation and help text updated
- **BREAKING**: Complete architectural shift to Claude Code plugin system
  - Projects now generate distributable plugins instead of local configurations
  - Agent knowledge bases stored globally at `~/.claude/agents/<plugin-name>-<agent-name>/knowledge/`
  - Plugin-local manifests track sources for team collaboration
- **BREAKING**: Agent knowledge bases moved from `.aircana/agents/` to global `~/.claude/agents/`
  - Agent files remain in plugin's `agents/` directory
  - Actual knowledge content stored globally to avoid version control bloat
  - Per-agent manifests track sources for reproducibility
- **BREAKING**: Hook scripts moved from `.aircana/hooks/` to plugin `scripts/` directory
  - Hooks configured via `hooks/hooks.json` manifest
  - All Claude Code artifacts consolidated in plugin structure
  - Global Aircana configuration remains in `~/.aircana`
- Enhanced agent templates with improved knowledge base usage instructions
- Improved CLI help text and command organization

### Removed
- Removed `relevant_files` feature entirely
  - Feature was not widely used and added unnecessary complexity
  - Removed commands: `air-add-relevant-files`
  - Removed stale references in templates and CLI help text
- Removed multi-root project support for simplicity

### Fixed
- Hook installation and generation issues in plugin initialization
- Agent knowledge refresh script generation
- Plugin manifest validation and structure

### Migration Guide
To upgrade from a previous version:
1. Update any scripts or documentation that reference `aircana install` to use `aircana init` instead
2. Projects should be re-initialized as plugins:
   ```bash
   aircana init --plugin-name your-plugin-name
   ```
3. Recreate agents and refresh knowledge:
   ```bash
   aircana agents create
   aircana agents refresh-all
   ```
4. Old `.aircana` local directories are no longer used (except `~/.aircana` for global config)

## [1.5.0] - 2025-09-28

### Added
- New Jira agent: Specialized agent for Jira MCP tool interactions, handles reading and writing tickets efficiently
- New `air-write-plan` command: Generates command for writing structured plans to files
- Write plan command generator for creating plan documentation templates

### Changed
- Enhanced planner agent with improved workflow split into smaller, focused chunks
- Updated planner agent to utilize todo list file management for better task tracking
- Improved planner instructions with clearer guidance for each planning phase
- Updated README with additional documentation

### Fixed
- Fixed test spec that previously required running locally for proper execution

## [1.4.0] - 2025-09-27

### Added
- New planner agent: Strategic project planning agent that integrates with Jira and collaborates with other sub-agents
- New plan command: `aircana generate` now creates an `air-plan.md` command for Claude Code
- Planner agent template with comprehensive workflow for ticket verification, requirements gathering, and sub-agent consultation

### Changed
- Improved knowledge base usage phrasing in agent templates
- Updated agent knowledge base instructions to use more efficient file listing approach
- Added planner to available default agents list

## [0.1.0] - 2025-09-03

### Added
- Initial release
- Context management for AI agents
- File organization utilities
- Template generation
- Claude Code integration
- CLI interface with Thor
- Commands: add_files, clear_files, dump_context, generate, install
