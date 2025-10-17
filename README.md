# Aircana

[![Ruby](https://github.com/westonkd/aircana/actions/workflows/main.yml/badge.svg)](https://github.com/westonkd/aircana/actions/workflows/main.yml)
[![Gem Version](https://badge.fury.io/rb/aircana.svg)](https://badge.fury.io/rb/aircana)

## Intro

Aircana is a CLI for generating [Claude Code plugins](https://docs.claude.com/en/docs/claude-code/plugins) with specialized knowledge bases. Each knowledge base provides curated documentation synced from Confluence (label-based) or web URLs, yielding more relevant, predictable, and project-specific results than general-purpose AI assistance.

Knowledge bases automatically refresh once daily on session start, keeping content up-to-date without manual intervention. Knowledge sources are tracked in version-controlled manifests, so team members can independently refresh content while keeping actual documentation out of git.

## How can I try it?

### Installation

Install the gem:

```bash
gem install aircana
```

Verify installation and dependency setup:

```bash
aircana doctor
```

### Quick Start

Create a new Claude Code plugin:

```bash
# Create a new plugin directory
mkdir my-plugin
cd my-plugin

# Initialize the plugin
aircana init

# Or initialize with a custom name
aircana init --plugin-name my-custom-plugin
```

This creates a plugin structure with:
- `.claude-plugin/plugin.json` - Plugin manifest
- `agents/` - Knowledge base definitions
- `commands/` - Slash commands
- `hooks/` - Hook configurations (hooks.json)
- `scripts/` - Hook scripts and utilities

### Next Steps

**1. Create a specialized knowledge base:**
```bash
aircana kb create
```

**2. Add knowledge sources:**
```bash
# From Confluence (requires configuration)
aircana kb refresh my-kb

# From web URLs
aircana kb add-url my-kb https://docs.example.com
```

**3. Manage your plugin:**
```bash
# View plugin information
aircana plugin info

# Update plugin metadata
aircana plugin update

# Bump version
aircana plugin version bump patch

# Validate plugin structure
aircana plugin validate
```

**4. Install plugin in Claude Code:**
- Copy your plugin directory to a location Claude Code can access
- Use Claude Code's plugin installation commands to enable your plugin

### Things to try

- Follow the [Getting Started](#getting-started) tutorial to create knowledge bases—Aircana's key differentiator

- Configure the Confluence integration and create domain-specific knowledge bases

- Use the `/ask-expert` command to consult multiple specialized experts

- Set up the development workflow with plan, execute, review, and apply-feedback commands

- Explore other tools by running `aircana --help`

## Getting Started

This tutorial walks through creating a complete Claude Code plugin with knowledge bases backed by Confluence, then publishing it to a marketplace for team distribution.

### Prerequisites

1. **Install Aircana:**
```bash
gem install aircana
aircana doctor  # Verify dependencies
```

2. **Configure Confluence (optional but recommended):**

Add to your shell profile (`.bashrc`, `.zshrc`, etc.):
```bash
export CONFLUENCE_BASE_URL="https://your-company.atlassian.net"
export CONFLUENCE_USERNAME="your.email@company.com"
export CONFLUENCE_API_TOKEN="your-generated-token"
```

To generate a Confluence API token:
1. Go to your Confluence instance
2. Click profile picture → **Account Settings** → **Security**
3. Select **Create and manage API tokens** → **Create API token**
4. Copy the token and add to your environment variables

Reload your shell: `source ~/.zshrc` (or your shell config file)

### Step 1: Create Your Plugin

```bash
# Create a new directory for your plugin
mkdir my-team-plugin
cd my-team-plugin

# Initialize the plugin
aircana init --plugin-name my-team

# Verify the structure was created
ls -la
```

This creates:
- `.claude-plugin/plugin.json` - Plugin manifest with metadata
- `agents/` - Directory for knowledge base definitions
- `commands/` - Custom slash commands
- `hooks/hooks.json` - Hook configurations
- `scripts/` - Hook scripts and utilities

### Step 2: Create a Knowledge Base Backed by Confluence

```bash
aircana kb create
```

You'll be prompted for:
- **Knowledge base name**: e.g., "backend-api" (use kebab-case)
- **Description**: e.g., "Expert in backend API development and best practices"
- **Model**: Choose sonnet (smarter), haiku (faster), or inherit (uses default)
- **Color**: Pick an interface color for visual identification

The knowledge base file is created at `agents/backend-api.md` with:
- Configuration (name, description, model)
- Knowledge base path reference
- Custom instructions

### Step 3: Tag Confluence Pages

In Confluence, label pages you want the knowledge base to access:

1. Open a relevant Confluence page (e.g., "API Design Guidelines")
2. Click **...** → **Edit labels**
3. Add label: `backend-api` (must match your knowledge base name)
4. Click **Save**

Repeat for all documentation pages relevant to this knowledge base. Aircana will discover pages by label during the refresh process.

**Tip:** Use a consistent labeling strategy. For example, label all backend documentation with `backend-api`, all frontend docs with `frontend-expert`, etc.

### Step 4: Refresh Knowledge Base

```bash
aircana kb refresh backend-api
```

This will:
1. Search Confluence for pages labeled `backend-api`
2. Download page content via Confluence REST API
3. Convert HTML to Markdown using ReverseMarkdown
4. Store content in the knowledge base directory
5. Update `agents/backend-api/manifest.json` with source metadata

**Output:** Knowledge files are created in `~/.claude/skills/backend-api/`

**Note:** The actual knowledge content is stored globally (not in your plugin directory) to avoid version control bloat and potential sensitive information leaks. Only the manifest (source tracking) is version controlled.

### Step 5: Add Web URLs (Optional)

You can also add public web documentation to your knowledge base:

```bash
aircana kb add-url backend-api https://docs.example.com/api-guide
aircana kb add-url backend-api https://restfulapi.net/rest-architectural-constraints/
```

This downloads the web page, extracts main content (removes nav/ads/scripts), converts to Markdown, and adds it to the knowledge base.

Refresh to sync web URLs:
```bash
aircana kb refresh backend-api
```

### Step 6: Use Your Knowledge Base

Your knowledge base is now ready! Claude Code will automatically use it when appropriate based on the description. You can also explicitly invoke it:

```
Ask backend-api to review this API endpoint design
Ask backend-api how to implement authentication
```

Claude has access to all Confluence pages and web URLs you've synced to the knowledge base.

### Step 7: Share Your Plugin with Your Team

For detailed instructions on distributing your plugin via Git repositories or Claude Code plugin marketplaces, see the official [Claude Code Plugin Marketplaces documentation](https://docs.claude.com/en/docs/claude-code/plugin-marketplaces).

**Quick summary:**
- Share via Git repository: Team members clone the plugin, configure Confluence credentials, and run `aircana kb refresh-all`
- Publish to a marketplace: Create a marketplace.json file in a separate repository, add your plugin metadata, and team members install via the marketplace UI

### Next: Keep Knowledge Up-to-Date

As your Confluence documentation evolves:

```bash
# Refresh a specific knowledge base
aircana kb refresh backend-api

# Or refresh all knowledge bases at once
aircana kb refresh-all
```

Knowledge sources are tracked in `agents/<kb-name>/manifest.json`, so team members can independently refresh without manual coordination.

## Key Concepts

### Plugins

Aircana creates Claude Code plugins - portable, distributable packages that extend Claude Code with custom functionality. Each plugin includes:
- **Manifest**: Metadata describing the plugin (name, version, author, etc.)
- **Knowledge Bases**: Specialized domain expertise from curated documentation
- **Commands**: Custom slash commands
- **Hooks**: Event-driven automation

Plugins can be shared with teams or published to plugin marketplaces for broader distribution.

#### Plugin Manifest Structure

The `.claude-plugin/plugin.json` file defines plugin metadata:

```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "Brief plugin description",
  "author": {
    "name": "Author Name",
    "email": "[email protected]",
    "url": "https://github.com/author"
  },
  "homepage": "https://docs.example.com/plugin",
  "repository": "https://github.com/author/plugin",
  "license": "MIT",
  "keywords": ["keyword1", "keyword2"]
}
```

Optional path overrides (for non-standard layouts):
```json
{
  "commands": "./custom/commands/",
  "agents": "./custom/skills/",
  "hooks": "./config/hooks.json",
  "mcpServers": "./mcp-config.json"
}
```

### Knowledge Bases

Aircana creates human-curated knowledge bases that provide Claude Code with domain-specific expertise. Each knowledge base:
- **Provides focused documentation**: Access to curated domain-specific content
- **Stays up-to-date**: Refreshable sources from Confluence and web URLs
- **Improves responses**: More relevant, predictable results with less back-and-forth
- **Custom configuration**: Model, color, and behavior settings

Knowledge bases support multiple source types and can be refreshed to pull the latest content. **Aircana-generated plugins automatically refresh all knowledge bases once daily on session start** via the SessionStart hook, keeping content up-to-date without manual intervention.

#### Confluence

To add a Confluence page to a knowledge base, label the desired page in Confluence, then run `aircana kb refresh <KB-NAME>`.

Aircana will also pull any Confluence pages labeled with a matching knowledge base name during initial creation (`aircana kb create`).

See the Confluence setup guide or run `aircana doctor` for instructions on setting up Confluence integration.

#### Websites

In addition to Confluence sources, Aircana allows adding arbitrary public websites to a knowledge base.

Websites are also refreshed when `aircana kb refresh <KB-NAME>` is used.

#### Structure

Knowledge bases are stored within the plugin's agents directory. For example:

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   ├── backend-expert.md
│   └── backend-expert/
│       ├── knowledge/          # (optional, for local KBs)
│       │   ├── API-Design.md
│       │   └── Authentication.md
│       └── manifest.json
├── commands/
│   └── ask-expert.md
├── hooks/
│   └── hooks.json
└── scripts/
    ├── pre_tool_use.sh
    └── session_start.sh
```

Knowledge base files and manifests are co-located in the plugin's `agents/` directory.

**Version Control Considerations:**

In many cases, adding the actual knowledge base to version control is undesirable because:
- Knowledge bases may contain numerous files, bloating repository size
- Content may include sensitive information not suitable for public repos
- Knowledge refreshes would create frequent, large commits

Aircana manages a per-knowledge-base `manifest.json` file to track knowledge sources without committing the actual content. Team members can refresh knowledge bases using `aircana kb refresh`.

For remote knowledge bases, actual content is stored in `~/.claude/skills/<kb-name>/`. For local knowledge bases, content is version-controlled in `agents/<kb-name>/knowledge/` and synced to the runtime location.

### Plugin Artifacts

Aircana uses ERB templates to generate plugin components consistently:
- **Knowledge Bases (Skills)**: Domain expertise with curated documentation
- **Commands**: Slash commands with parameter handling
- **Hooks**: Event handlers for automation

These templates promote best practices and help create effective plugin components without extensive trial and error.

### SQS Integration (Slack Integration at Instructure)

Aircana uses the "Notification" Claude Code hook to send messages to SQS.

At Instructure this means you can easily configure Claude Code to send you slack messages when it needs your attention via Aircana

(Instructions coming soon, send a message if you want help with this)

## Best Practices

### Designing Effective Knowledge Bases

**Design knowledge bases as narrow domain experts, not generalists.** More granular knowledge bases with focused content generally perform better than broad, general-purpose ones.

**Examples:**

✅ **Good - Narrow domains:**
- `database-schema-expert` - Database design, migrations, indexing strategies
- `api-authentication-expert` - OAuth, JWT, session management
- `frontend-styling-expert` - CSS, design systems, responsive layouts

❌ **Avoid - Too broad:**
- `backend-engineer` - Too many domains, knowledge becomes unfocused
- `full-stack-developer` - Overlapping responsibilities with unclear boundaries

**Why narrow domains work better:**
- **Focused content**: Each knowledge base contains highly relevant documentation for a specific domain
- **Better results**: More accurate, detailed responses within the area of expertise
- **Less context pollution**: Smaller, focused content prevents information overload
- **Clear boundaries**: Non-overlapping domains reduce confusion

**Tips:**
- Break large domains into smaller, specialized areas
- Each knowledge base should have a clear, distinct purpose
- Knowledge bases should contain 5-20 highly relevant documents, not 100+ loosely related ones
- Use descriptions to clearly define boundaries and expertise areas

## Development Workflow

Aircana provides a complete development lifecycle through five integrated slash commands:

```mermaid
stateDiagram-v2
    [*] --> Plan: /plan
    Plan --> Record: /record
    Record --> Execute: /execute
    Execute --> Review: /review
    Review --> ApplyFeedback: /apply-feedback
    ApplyFeedback --> Review: More issues found
    ApplyFeedback --> [*]: Satisfied
```

### Quick Overview

1. **`/plan`** - Create strategic implementation plan
2. **`/record`** - Save plan to Jira ticket
3. **`/execute`** - Implement plan and create commit
4. **`/review`** - Adversarial code review with expert feedback
5. **`/apply-feedback`** - Apply review changes and amend commit

### Command Details

#### 1. `/plan` - Strategic Planning

Creates a high-level implementation plan by:
- Asking you to specify relevant files and directories
- Consulting specialized sub-agents for domain expertise
- Sharing research context to avoid duplicate work
- Generating a focused strategic plan (what to do, not how)
- Creating actionable todo checklist

The planner focuses on architecture decisions and approach, avoiding exhaustive code implementations.

#### 2. `/record` - Save to Jira

Records your approved plan to a Jira ticket by:
- Taking the ticket key/ID as input
- Delegating to the `jira` sub-agent for MCP operations
- Storing the plan in the ticket description or comments

This creates a traceable link between planning and execution.

#### 3. `/execute` - Implementation

Executes the strategic plan by:
- Reading the plan from the Jira ticket
- Creating detailed implementation todo list
- Presenting plan for your approval
- Implementing changes sequentially
- Writing unit tests (delegates to test-writing sub-agent if available)
- Running tests to verify implementation
- Creating git commit (delegates to git-ops sub-agent if available)

After commit creation, suggests running `/review`.

#### 4. `/review` - Adversarial Review

Conducts comprehensive code review of HEAD commit by:
- Analyzing changed files to identify technical domains
- Using sub-agent-coordinator to select relevant expert agents
- Presenting changes to experts in parallel
- Synthesizing feedback organized by severity (Critical/Important/Suggestions)
- Storing review output for next step

Explicitly states "Reviewing: <commit message>" and ends with "Run /apply-feedback".

#### 5. `/apply-feedback` - Apply Changes

Applies code review feedback by:
- Reading review output from conversation context
- Creating prioritized change plan (critical issues first)
- Presenting plan for your approval
- Applying approved changes
- Re-running unit tests
- Fixing any test failures
- **Amending HEAD commit** with improvements using `git commit --amend --no-edit`

This preserves the original commit message while incorporating review improvements in a single commit.

### Usage Example

```bash
# 1. Start planning
/plan
> Specify relevant files: src/api/, spec/api/

# 2. Save plan to ticket
/record PROJ-123

# 3. Execute implementation
/execute PROJ-123

# 4. Review the commit
/review

# 5. Apply feedback
/apply-feedback
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
aircana init
aircana hooks enable notification_sqs
```

Reload your shell or run `source ~/.zshrc` (or your shell config file).

### Verify Configuration

```bash
aircana doctor
```

This will check if Confluence and other integrations are properly configured.

## All Commands

### Plugin Management
```bash
aircana init [DIRECTORY]           # Initialize a new plugin (defaults to current directory)
aircana init --plugin-name NAME    # Initialize with custom plugin name
aircana plugin info                # Display plugin information
aircana plugin update              # Update plugin metadata
aircana plugin version             # Show current version
aircana plugin version bump [TYPE] # Bump version (major, minor, or patch)
aircana plugin version set         # Set specific version
aircana plugin validate            # Validate plugin structure
```

### Knowledge Base Management
```bash
aircana kb create                  # Create new knowledge base interactively
aircana kb refresh [KB-NAME]       # Sync knowledge base from Confluence and web sources
aircana kb refresh-all             # Refresh all knowledge bases
aircana kb add-url [KB-NAME] [URL] # Add a web URL to a knowledge base
aircana kb list                    # List all configured knowledge bases
```

### Hook Management
```bash
aircana hooks list                 # List all available and installed hooks
aircana hooks enable [HOOK]        # Enable a specific hook
aircana hooks disable [HOOK]       # Disable a specific hook
aircana hooks create               # Create custom hook
aircana hooks status               # Show hook configuration status
```

### System
```bash
aircana generate                   # Generate plugin components from templates
aircana doctor                     # Check system health and dependencies
aircana doctor --verbose           # Show detailed dependency information
aircana dump-context [KB-NAME]     # View current context for knowledge base
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

Run commands in development with `bundle exec exe/aircana <command>`

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/westonkd/aircana.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
