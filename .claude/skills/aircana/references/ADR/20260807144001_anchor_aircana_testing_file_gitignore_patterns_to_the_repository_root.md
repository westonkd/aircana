# Anchor Aircana testing-file gitignore patterns to the repository root

- **Status**: Accepted
- **Date**: 2026-08-07

## Context

Aircana generates `hooks/`, `scripts/`, `skills/`, and `agents/` at the root of whatever
directory it runs in. Because this repo is itself used to exercise the CLI, those four
directories get created at the repo root during development and must not be committed.
`.gitignore` handled this with four bare patterns:

```
hooks
scripts
skills
agents
```

A gitignore pattern with no slash matches a path component at any depth, not just at the
root. So `skills` also matched `lib/aircana/templates/skills/`, `.claude/skills/`, and any
other nested directory of that name. The existing `!lib/aircana/templates/agents/` negation
at the bottom of the file is a patch for exactly this over-match.

Adding a project-context skill at `.claude/skills/aircana/` hit the same problem from a new
direction. `.claude/` was ignored wholesale, and even after switching to content-level
ignores with negations, the bare `skills` and `scripts` patterns appear later in the file and
last-match-wins, so they re-ignored both the skill directory and its `scripts/` subdirectory.

Two options:

1. Append more negations at the end of `.gitignore`, after the bare patterns, so ordering
   puts them last.
2. Anchor the four testing-file patterns to the root with a leading slash, matching what they
   actually mean.

## Decision

Anchor them: `/hooks`, `/scripts`, `/skills`, `/agents`. Also change `.claude/` to
content-level ignores so git will descend into it:

```
.claude/*
!.claude/skills/
.claude/skills/*
!.claude/skills/aircana/
```

A trailing-slash directory ignore (`.claude/`) cannot be undone by negating something
underneath it, because git never descends into an excluded directory. Ignoring the directory's
contents instead is the only way to re-include a subtree.

Option 1 was rejected because it leaves the root cause in place. Every future nested `skills`
or `scripts` directory would need its own negation, and the negation stack has to stay
ordered after the bare patterns, which is a non-obvious constraint for anyone editing the
file later.

## Consequences

- `.claude/skills/aircana/` is version controlled, so the PRD, DESIGN notes, and this ADR log
  travel with the repo instead of living on one machine. Everything else under `.claude/`,
  including `settings.local.json`, stays ignored.
- The four generated root directories are still ignored, verified against `git status`: the
  anchoring change un-ignored nothing that was previously ignored.
- Nested directories named `hooks`, `scripts`, `skills`, or `agents` are no longer ignored by
  accident. That is the intended behavior for `lib/aircana/templates/`, whose contents are
  supposed to be tracked, but it means a future generated nested directory will need its own
  explicit rule.
- `!lib/aircana/templates/agents/` is now redundant. Left in place rather than removed, since
  deleting it is a separate cleanup with no benefit here. (Removed later, along with `/agents`,
  by
  [20260807152554_drop_agent_artifacts_in_favor_of_skills_only_generation](20260807152554_drop_agent_artifacts_in_favor_of_skills_only_generation.md),
  which deleted both targets.)
- Any other project skill added under `.claude/skills/` stays ignored unless it gets its own
  negation. That is deliberate: opt in per skill rather than committing every local skill.
