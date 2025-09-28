# Aircana

A Ruby CLI utility for context management and Claude Code integration. Aircana helps manage relevant files for development sessions, create specialized Claude Code agents, and optionally sync knowledge from Confluence.

[![Ruby](https://github.com/westonkd/aircana/actions/workflows/main.yml/badge.svg)](https://github.com/westonkd/aircana/actions/workflows/main.yml)
[![Gem Version](https://badge.fury.io/rb/aircana.svg)](https://badge.fury.io/rb/aircana)

## Installation

Install the gem:

```bash
gem install aircana
```

Or add to your Gemfile:

```ruby
gem 'aircana'
```

Then run:

```bash
bundle install
```

Verify installation and check dependencies:

```bash
aircana doctor
```

## Prerequisites

### Required Dependencies
- Ruby >= 3.3.0
- `git` (version control operations)
- `fzf` (interactive file selection)

### Optional Dependencies
- `bat` (enhanced file previews, falls back to `cat`)
- `fd` (faster file searching, falls back to `find`)

### For Confluence Integration (Optional)
- Access to a Confluence instance
- Confluence API token
- Appropriate permissions to read pages and labels

## Core Concepts

Aircana provides two main independent features:

### 1. Relevant Files Management
Track and manage a curated set of "relevant files" - the current working set of important files for your development session. This context is automatically available to Claude Code sessions.

**This works completely independently from agents** - you can use relevant files without creating any agents.

### 2. Specialized Agents (Optional)
Create Claude Code agents with:
- **Domain Knowledge**: Focused expertise in specific areas
- **Confluence Integration**: Knowledge sync from labeled pages (requires Confluence setup)
- **Customizable Models**: Choose from different Claude models and interface colors

**Agents work independently from relevant files** - you can create agents without managing relevant files.

### Knowledge Sources
- **Relevant Files**: Current working set managed by Aircana (independent feature)
- **Confluence Pages**: Fetched based on agent labels (agent feature, requires setup)
- **Web URLs**: Any web content added to agent knowledge bases (HTML converted to Markdown)
- **Local Context**: Project-specific files and configurations

## What Aircana Does

- **File Context Management**: Track and manage relevant files for Claude Code sessions
- **Agent Configuration**: Create and configure specialized Claude Code agents
- **Confluence Integration**: Sync knowledge from Confluence pages to agents (optional)
- **Claude Code Shortcuts**: Quick-launch Claude Code with pre-configured agents
- **System Health Checks**: Validate dependencies and configuration

## Quick Start

1. **Install and verify**:
   ```bash
   gem install aircana
   aircana doctor
   ```

2. **Set up your project**:
   ```bash
   cd your-project
   aircana generate
   aircana install    # Set up Aircana integration in this project
   ```

3. **Add files to context**:
   ```bash
   aircana files add    # Interactive selection
   ```

   Then in Claude Code, include them whenever you want to reload the files into the current context:
   ```
   /add-relevant-files
   ```

4. **Create an agent** (optional, but powerful with Confluence):
   ```bash
   aircana agents create    # Tag Confluence pages with the agent's name before or after creation to pull that knowledge into the agent's knowledge base. 
   ```

5. **View your current context**:
   ```bash
   aircana files list     # See all tracked files
   aircana agents list    # See all configured agents
   ```

## Configuration (Optional)

### Confluence Setup (Optional)

To use agent knowledge sync features, you'll need to configure Confluence integration:

#### 1. Generate Confluence API Token

1. Go to your Confluence instance
2. Click your profile picture → **Account Settings**
3. Select **Security** → **Create and manage API tokens**
4. Click **Create API token**
5. Give it a descriptive name (e.g., "Aircana Integration")
6. Copy the generated token

#### 2. Set Environment Variables

Add these to your shell profile (`.bashrc`, `.zshrc`, etc.):

```bash
export CONFLUENCE_BASE_URL="https://your-company.atlassian.net"
export CONFLUENCE_USERNAME="your.email@company.com"
export CONFLUENCE_API_TOKEN="your-generated-token"
```

### SQS Notifications Setup (Optional)

To enable SQS notifications for Claude Code events (useful for Slack/Teams integration):

#### 1. Install AWS CLI

Make sure you have the AWS CLI installed:

```bash
# macOS
brew install awscli

# Ubuntu/Debian
apt install awscli

# Configure AWS credentials
aws configure
```

#### 2. Set Environment Variables

Add these to your shell profile (`.bashrc`, `.zshrc`, etc.):

```bash
export AIRCANA_SQS_QUEUE_URL="https://sqs.us-east-1.amazonaws.com/your-account/your-queue"
export AIRCANA_SQS_MESSAGE_TEMPLATE='{"channel":"changelog","username":"Aircana","text":"{{message}}"}'
export AWS_REGION="us-east-1"
```

The message template supports `{{message}}` placeholder which gets replaced with the Claude Code notification text.

#### 3. Install and Enable Hook

```bash
aircana generate
aircana install
aircana hooks enable notification_sqs
```

Reload your shell or run `source ~/.zshrc` (or your shell config file).

### Verify Configuration

```bash
aircana doctor
```

This will check if Confluence and other integrations are properly configured.

## Agent Workflow Tutorial

Here's a complete example of creating an agent and syncing knowledge from Confluence:

### 1. Create an Agent

```bash
aircana agents create
```

You'll be prompted for:
- **Agent name**: e.g., "backend-api"
- **Description**: e.g., "Helps with backend API development"
- **Model**: Choose from sonnet, haiku, or inherit
- **Color**: Choose interface color

### 2. Tag Confluence Pages

In Confluence, add the label `backend-api` (matching your agent name) to relevant pages:

1. Open a Confluence page with relevant documentation
2. Click **...** → **Edit labels**
3. Add label: `backend-api`
4. Save

Repeat for all pages you want the agent to know about.

### 3. Add Knowledge Sources

**From Confluence:**
```bash
aircana agents refresh backend-api
```

This downloads all Confluence pages labeled `backend-api` and makes them available to your agent.

**From Web URLs:**
```bash
aircana agents add-url backend-api https://docs.example.com/api-guide
aircana agents add-url backend-api https://blog.example.com/best-practices
```

This fetches web content and converts it to Markdown for your agent's knowledge base.

### 4. Use the Agent

Once created with a good description, Claude Code will automatically use your agent when appropriate during conversations. You can also explicitly request a specific agent:

```
Ask backend-api for a code review of this function
Ask backend-api to help debug this API endpoint
Ask rspec-test-writer to write and run tests for @file
```

The agent will have access to all the Confluence knowledge you synced.

### 5. Update Knowledge

Whenever you update Confluence pages, add new ones with the agent label, or want to refresh web content:

```bash
aircana agents refresh backend-api
```

This refreshes both Confluence pages and web URLs associated with the agent.


## All Commands

### File Management
```bash
aircana files add         # Interactively select files to add to context
aircana files add-dir [PATH] # Add all files from directory to context
aircana files clear       # Clear current file context
aircana files list        # Show current relevant files
```

### Agent Management
```bash
aircana agents create     # Create new agent interactively
aircana agents refresh [AGENT] # Sync agent knowledge from Confluence and web sources
aircana agents add-url [AGENT] [URL] # Add a web URL to an agent's knowledge base
aircana agents list       # List all configured agents
```

### Hook Management
```bash
aircana hooks list        # List all available and installed hooks
aircana hooks enable [HOOK] # Enable a specific hook
aircana hooks disable [HOOK] # Disable a specific hook
aircana hooks create      # Create custom hook
aircana hooks status      # Show hook configuration status
```

### Project Management
```bash
aircana project init     # Initialize multi-root project configuration
aircana project add [PATH] # Add folder to multi-root configuration
aircana project remove [PATH] # Remove folder from multi-root configuration
aircana project list     # List all configured folders and agents
aircana project sync     # Manually sync symlinks for multi-root agents
```

### System
```bash
aircana generate         # Generate Claude Code configuration files
aircana install          # Install generated files to Claude Code
aircana doctor           # Check system health and dependencies
aircana doctor --verbose # Show detailed dependency information
aircana dump-context [AGENT] # View current context for agent
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

Run commands in development with `bundle exec exe/aircana <command>`

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/westonkd/aircana.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
