# PRD: aircana

> **Status (2026-08-07):** Written retrospectively against an already-shipped gem, so this
> describes the product as it exists rather than a plan. Updated for v6.0.0, which made
> generation skills-only. Load-bearing decisions already made and reflected below: everything
> for a knowledge base lives in one directory, `skills/<kb-name>/`, holding `SKILL.md`,
> `manifest.json`, and the fetched Markdown; Claude Code's native Skills format is the only
> output artifact; Confluence discovery is label-based; and refresh is manual. `README.md` and
> `CLAUDE.md` were corrected in 6.0.0 and no longer contradict this document, which closes the
> storage-layout half of OQ1.

## Summary

Aircana is a Ruby CLI that generates and maintains [Claude Code
plugins](https://docs.claude.com/en/docs/claude-code/plugins) whose main payload is curated
knowledge bases. A user runs `aircana init` to scaffold a plugin, `aircana kb create` to
define a narrow domain knowledge base, then labels the relevant Confluence pages or adds web
URLs. `aircana kb refresh` pulls those sources down, converts them to Markdown, and writes
them into the plugin's `skills/` directory where Claude Code picks them up. The sources are
tracked in a per-KB `manifest.json` that is version controlled, while the fetched content
generally is not, so a team shares the recipe for a knowledge base rather than a snapshot of
it.

## Problem

General-purpose AI assistance answers from general knowledge, which produces plausible but
wrong answers about a specific company's systems: the internal auth flow, the sharding
strategy, the deploy runbook, the team's migration conventions. The authoritative version of
that knowledge usually already exists in Confluence and scattered web docs, but it is not in
the model's context and copying it in by hand does not scale or stay current.

Assembling this by hand has concrete costs:

- Curating documentation into a plugin is manual, and it goes stale the day after it's done.
- Committing fetched documentation into a repo bloats it, produces large recurring diffs on
  every refresh, and risks publishing internal content in a repo that may be public.
- Writing plugin manifests, skill files, hooks, and slash commands by hand is boilerplate
  work with easy-to-get-wrong formats.
- Confluence storage-format HTML is not Markdown, and its structured macros (code blocks,
  info panels, TOCs, Jira embeds) mangle badly under naive conversion, silently truncating
  page content.

The people who feel this are engineers on a team large enough to have real internal
documentation, and the plugin author who wants to distribute domain expertise to their
teammates without also distributing the documents.

## Goals

- One command scaffolds a valid, installable Claude Code plugin.
- Defining a knowledge base and pointing it at sources takes minutes, not a doc-wrangling
  session.
- Knowledge stays current without anyone remembering to refresh it.
- A knowledge base can be shared through git as a source recipe, so teammates fetch content
  themselves under their own credentials.
- Fetched content is faithful to the source, in particular no silent truncation of
  Confluence pages.
- Failure modes are legible to a non-expert: `aircana doctor` says what is missing and how to
  fix it.

## Non-goals

- Not a general documentation site generator or a docs search engine. The output target is
  specifically Claude Code plugins.
- Not a Confluence client. Only the read paths needed for label discovery and page fetch are
  supported, and there is no authoring or write-back.
- Not a hosted service. There is no server, no shared index, and no central store. Every
  user refreshes locally with their own credentials.
- Not responsible for plugin distribution. Publishing to a marketplace is Claude Code's
  concern and is delegated to its documentation.
- No semantic search, chunking, embedding, or vector store. Knowledge bases are curated
  files, and curation is the human's job.
- Not a replacement for writing good documentation. Aircana propagates whatever quality
  exists upstream.

## Users

- **Plugin author** (primary). Owns a plugin repo, decides how to slice domains into
  knowledge bases, chooses the Confluence labels, and runs the version-bump and validate
  commands. Needs the generated structure to be correct without having to learn the plugin
  spec.
- **Teammate consuming the plugin.** Installs the plugin, configures Confluence credentials
  once, and otherwise wants refresh to be invisible. Needs the manifest to be enough to
  reconstruct the knowledge base locally.
- **Claude Code itself,** as a consumer of the generated artifacts. Needs frontmatter,
  descriptions, and file layout that match what it actually loads, and needs `SKILL.md`
  descriptions specific enough to route the right question to the right knowledge base.

## Vocabulary

- **Knowledge base (KB)** — a named narrow domain of expertise, rendered as one Agent Skill:
  `skills/<kb-name>/SKILL.md` plus sibling content files. Historically also called an
  "agent" or "expert"; the old name survives only in the `/ask-expert` command name.
- **Manifest** — `skills/<kb-name>/manifest.json`, alongside the skill it describes. Schema
  version `1.0`. Records the list of sources (Confluence label plus page IDs, web URLs). This
  is the durable definition of a KB, and the only part of one that cannot be refetched.
- **Plugin mode** — a directory containing `.claude-plugin/plugin.json`. Switches path
  resolution to `skills/` at the repo root. Without it, non-plugin mode puts everything under
  `.claude/skills/` for one-off local use.
- **Refresh** — re-running discovery and fetch for every source in a KB's manifest.
  Label-based, so it picks up pages newly labeled upstream, not just pages already listed.
- **Source** — one entry in a manifest. Currently `confluence` or `web`.

## Requirements

### Plugin lifecycle

- **R1** `aircana init [DIRECTORY]` scaffolds `.claude-plugin/plugin.json`, `skills/`,
  `commands/`, `hooks/hooks.json`, and `scripts/`, with an optional `--plugin-name`.
- **R2** `aircana plugin info|update|validate` inspect, edit, and check the manifest.
  Validation covers plugin structure and manifest fields, and hook event names are validated
  against the known set. Structure validation must check the directories aircana actually
  generates.
- **R3** `aircana plugin version [bump major|minor|patch|set]` manages the plugin's semantic
  version, distinct from the aircana gem's own version.
- **R4** Generated components come from ERB templates under `lib/aircana/templates/`, so
  format changes are made in one place and apply to every future generation.

### Knowledge bases

- **R5** `aircana kb create` interactively defines a KB and writes its manifest and
  `SKILL.md`.
- **R6** `aircana kb list` enumerates configured KBs; `aircana dump-context <kb-name>` prints
  the assembled content for debugging.
- **R7** `aircana kb add-url <kb-name> <url>` records an arbitrary HTTP(S) URL as a source.
- **R8** `aircana kb refresh <kb-name>` refreshes every source of a KB; `aircana kb refresh-all`
  does so for all of them.
- **R9** KB content is version controlled by default. A user who does not want a given KB's
  content committed gitignores that skill directory, keeping `manifest.json` tracked so
  teammates can refetch it.
- **R10** Path resolution honors `AIRCANA_PLUGIN_ROOT` and `CLAUDE_PLUGIN_ROOT`, and falls
  back to plugin-mode detection via `.claude-plugin/plugin.json`.
- **R23** The only generated knowledge artifact is the Skill. Aircana removes agent files it
  generated in earlier versions, and leaves hand-written ones alone.

### Source fetching

- **R11** Confluence discovery is by label: pages labeled with the KB name are found via the
  REST API, with pagination for large result sets. Credentials come from
  `CONFLUENCE_BASE_URL`, `CONFLUENCE_USERNAME`, and `CONFLUENCE_API_TOKEN`.
- **R12** Confluence storage-format HTML converts to Markdown without content loss. Code
  macros become fenced blocks with their language, and macros without a rich-text body are
  removed without swallowing adjacent content. This requirement is the source of most of the
  5.2.x fix line and should be treated as regression-prone.
- **R13** Web fetching extracts the main content region and drops navigation, headers,
  footers, ads, and scripts before Markdown conversion.
- **R14** Fetched pages get a meaningful title: the HTML `<title>` when usable, an
  LLM-generated title when it is generic or truncated, and the URL path as a last resort.
- **R15** The LLM provider is pluggable via `AIRCANA_LLM_PROVIDER`, defaulting to the Claude
  Code CLI with AWS Bedrock as an alternative for environments without it.
- **R16** Summaries are prefixed with `[kb-name]: ` so a consumer can tell which KB a given
  summary belongs to.

### Automation and operability

- **R17** `aircana init` installs `session_start` and `notification_sqs` hooks. Automatic daily
  refresh was removed in 5.0.0 along with remote KBs; refresh is now a manual step.
- **R18** `notification_sqs` posts Claude Code notifications to an SQS queue using
  `AIRCANA_SQS_QUEUE_URL` and a `{{message}}` template, for Slack-style alerting.
- **R19** `aircana doctor [--verbose]` reports on required dependencies (git, fzf), optional
  ones (bat, fd, aws-cli), and integration configuration, with remediation guidance. Its KB
  count must come from the directory aircana actually writes skills to.
- **R20** User-facing output is non-technical: `HumanLogger` for messaging,
  `ProgressTracker` for spinners and batch progress.

### Distribution and quality

- **R21** Ships as the `aircana` gem, Ruby >= 3.3.0, released via `rake release`.
- **R22** `rake` runs RSpec and RuboCop together, and is the gate for changes.

## Platform assessment / spikes

Not recorded for anything before v6.0.0. The project reached v5.2.7 without a written
evaluation log, so the alternatives weighed for the significant choices (Claude Code skills
format over a custom one, label-based Confluence discovery over explicit page lists,
ReverseMarkdown over another converter or the Confluence Markdown export, committing content
over the manifest-plus-gitignore model that preceded it) exist only as the shipped result.
Reconstructing them retroactively would be invention. New evaluations get an ADR at the time
they happen; the 6.0.0 skills-only decision is the first.

## Open questions

- **OQ1** *Resolved in 6.0.0.* `README.md` and `CLAUDE.md` both documented manifests under
  `agents/`, and the README also described a global `~/.claude/skills/<kb-name>/` content
  store and `agents/<kb-name>/knowledge/` for local KBs. None of that matched
  `configuration.rb`. Both files were corrected to the single-directory
  `skills/<kb-name>/` model. What remains open is the underlying process question: doc drift
  went unnoticed across at least two major versions, and nothing in `rake` would catch it
  happening again.
- **OQ2** Manifest schema is pinned at `1.0` with no stated migration path, and has now
  changed shape twice at that version: `kb_type` dropped in 5.0.0 and `color` dropped in
  6.0.0. Both relied on reads ignoring unknown keys, which works for removals but not for
  renames or a source type changing shape. What is the plan when one of those is needed?
- **OQ3** Confluence macro handling has regressed four times in the 5.2.x line (5.2.2,
  5.2.4, 5.2.5, 5.2.6, 5.2.7), each a regex fix for a different macro shape. Is incremental
  regex hardening the end state, or should storage-format handling move to a real parser?
- **OQ4** Nothing enforces the "narrow domain, 5-20 documents" guidance from the README's
  best practices. Should `kb create` or `plugin validate` warn when a KB grows beyond that?
- **OQ5** A refresh with expired or missing credentials, or an upstream page that was
  deleted or unlabeled, has no documented behavior. Does stale content survive, or get
  emptied? Now that content is committed, an emptying refresh shows up as a destructive diff
  rather than a silent local loss, which makes the answer more visible but no less important.
- **OQ6** Only Confluence and web sources exist. Are others (local files, GitHub, Google
  Docs, Jira) in scope, and does the manifest schema accommodate them without a version bump?

## Success criteria

- A newcomer goes from `gem install aircana` to a working plugin with one populated knowledge
  base by following the README, without reading source code.
- A teammate cloning a plugin repo has working knowledge bases immediately, and can rebuild
  any gitignored one with `kb refresh-all` plus credentials, with no coordination with the
  author.
- Fetched Confluence pages match their source: no truncation, code blocks intact, macro
  content preserved. Each historical truncation bug has a regression test.
- `rake` is green: RSpec and RuboCop both pass.
- `aircana doctor` and `aircana plugin validate` correctly identify a broken environment or
  plugin and say how to fix it. Both must report on the layout aircana currently generates,
  not a historical one.

## Phasing

Phases 1 through 5 have shipped. The version markers below are approximate, drawn from
`CHANGELOG.md` rather than from a plan written in advance.

1. **CLI and generation foundation.** Thor CLI, ERB templates, plugin scaffolding, path
   resolution, `doctor`. Shipped.
2. **Confluence integration.** Label discovery, REST v2 fetch with pagination, HTML to
   Markdown, manifest tracking. Shipped.
3. **Web sources and LLM assist.** URL fetching with content extraction, title generation,
   pluggable LLM provider. Shipped.
4. **Plugin-format alignment and hardening.** Migration to Claude Code's native
   `skills/<kb-name>/SKILL.md` layout, the remote versus local KB split and its removal in
   5.0.0, and the 5.2.x Confluence fidelity fixes. Shipped, and R12 remains the active
   maintenance burden.
5. **Skills-only consolidation.** Shipped as 6.0.0. Removed agent generation, `/plan`, and the
   `color` field; repointed `plugin validate` and `doctor` at `skills/`; corrected the storage
   layout in `README.md` and `CLAUDE.md`, resolving OQ1. Recorded in the first ADR.
6. **Fidelity and schema durability.** Next. Resolve OQ3 (parser versus regex for storage
   format) and OQ2 (manifest migration). Ordered ahead of new features because they are
   correctness and trust issues: content that silently truncates undermines every other
   feature, and the schema has now changed shape twice at version `1.0` without a stated plan.
7. **Additional source types and curation guardrails.** Later, and gated on phase 6, since
   OQ6 depends on the manifest schema question being settled.
