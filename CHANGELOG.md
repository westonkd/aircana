# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
