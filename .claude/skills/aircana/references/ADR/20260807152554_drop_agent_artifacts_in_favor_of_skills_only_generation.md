# Drop agent artifacts in favor of skills-only generation

- **Status**: Accepted
- **Date**: 2026-08-07

## Context

Aircana was built before Agent Skills existed, so it packaged knowledge bases as sub-agents.
Skills support arrived in 4.2.0, which moved `/ask-expert` to the Skill tool but left `/plan`
on `Task(subagent_type=...)`. Every release since has generated both artifact types for each
knowledge base. Skills are now the standard way to package knowledge for Claude Code, so
maintaining the agent half has no remaining upside.

The agent artifact was already vestigial. `base_agent.erb` produced eight lines whose entire
body was:

```
Use the skill "Learn Canvas Database" to learn your domain, then perform the requested task.
```

A caller that consults the skill directly gets the same knowledge without the indirection.

Two related discoveries shaped the scope:

- Manifests were never in `agents/`. `Contexts::Manifest` resolves paths through
  `kb_knowledge_dir`, which `Configuration` aliases to `skills_dir`, so manifests have lived at
  `skills/<kb-name>/manifest.json` since the Skills migration. `README.md` and `CLAUDE.md` both
  claimed `agents/<kb-name>/manifest.json`. `Configuration#agents_dir` had exactly one
  production reader: the agent generator's output path.
- Two commands were already broken in ways that removing `agents/` would have made obvious.
  `plugin validate` checked for `agents/` and never checked `skills/`, so it would have failed
  on every plugin created after this change. `doctor` counted knowledge bases by globbing a
  hardcoded `.claude/agents/*.md`, so it already reported "No knowledge bases configured" for
  every plugin-mode repo.

The `color` field was the other piece of agent-only surface. It was added to the manifest
schema in 5.1.1 solely to stop agent frontmatter colors changing on every refresh. Skills have
no color field, so it had no remaining consumer.

## Decision

Generate skills and nothing else. Delete `AgentsGenerator`, `templates/agents/`, and
`Configuration#agents_dir`.

Four sub-decisions worth recording, since each had a defensible alternative:

**Delete `/plan` rather than port it to Skills.** Its design is a coordinator that enumerates
available agents and fans out to them for isolated per-agent context. Skills share the caller's
context, so a ported version would be `/ask-expert` with different prose. Claude Code has
native plan mode, and `/ask-expert` already covers consulting knowledge bases.

**Remove `color` completely** rather than keeping the manifest API as dead-but-tested code.
`update_manifest` now deletes the key when it rewrites a manifest, mirroring how `kb_type` was
handled in 5.0.0. Reads are key-by-key, so old manifests carrying `color` stay valid.

**Clean up stale `agents/<kb-name>.md` on refresh,** guarded by a content check for the
generated marker `Use the skill "`. Aircana deletes only files it produced; a hand-written
agent is left alone. The alternative of documenting the cleanup and touching nothing leaves
dead files in every existing plugin, which Claude Code would keep loading as real agents. The
logic lives in `Migrations::LegacyAgentCleanup` rather than in `Configuration` or `KB`, so a
future major version can delete one file instead of untangling the legacy path resolution from
current code.

`commands/plan.md` is deliberately *not* auto-deleted, and the migration guide asks the user to
remove it. A slash command is much likelier to have been hand-edited than a generated agent
proxy, and unlike the agent files it has no reliable generated marker to check.

**Keep `agents` accepted in `plugin.json`.** `PluginManifest` validates against Claude Code's
schema, not against what aircana generates. Claude Code still supports agents, so rejecting a
hand-written `agents` path override would make aircana stricter than the platform. Added the
missing `skills` key to `OPTIONAL_FIELDS` and `PATH_OVERRIDE_FIELDS` at the same time; aircana's
primary output directory previously could not be path-overridden in a manifest it validates.

## Consequences

- One artifact per knowledge base instead of two. `SkillsGenerator` and `AgentsGenerator` had
  byte-identical description logic, so this also removes a silent divergence risk.
- `plugin validate` and `doctor` now report on what aircana actually produces. Both were fixed
  as part of this change rather than after, because removing `agents/` would have turned latent
  bugs into visible failures.
- Existing plugins need a one-time cleanup: `agents/` (automatic on refresh) and
  `commands/plan.md` (manual). Released as 6.0.0 with a migration guide.
- Manifest schema drops `color` without a version bump, on the same reasoning as the 5.0.0
  `kb_type` removal: unknown keys are ignored on read, so no migration is needed. This leaves
  OQ2 in the PRD unresolved, since the schema still has no stated migration path and has now
  changed shape twice at `1.0`.
- `.rubocop.yml` shed five excludes, four of which named
  `lib/aircana/cli/commands/agents.rb`, a file deleted several releases ago.
- The `!lib/aircana/templates/agents/` negation in `.gitignore`, flagged as redundant in
  [20260807144001_anchor_aircana_testing_file_gitignore_patterns_to_the_repository_root](20260807144001_anchor_aircana_testing_file_gitignore_patterns_to_the_repository_root.md),
  is removed along with `/agents`. Neither target exists now.
- Aircana keeps validating `agents` in `plugin.json`, so "skills-only" describes what aircana
  generates, not what it permits. If Claude Code ever drops agents, that key should go too.
