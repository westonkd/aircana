# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- **BREAKING**: Agent knowledge bases and manifests moved from `.aircana/agents/` to `.claude/agents/`
  - Agent files and their knowledge are now co-located in the `.claude/agents/` directory
  - This consolidates all Claude Code artifacts in one location

### Migration Guide
To upgrade from a previous version:
1. Move existing agent knowledge manually:
   ```bash
   mv .aircana/agents/*/* .claude/agents/
   ```
2. Or refresh all agent knowledge from sources:
   ```bash
   aircana agents refresh-all
   ```

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
