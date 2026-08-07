---
name: aircana
description: Project context for the aircana Ruby gem, which scaffolds and manages Claude Code plugins with Confluence/web-backed knowledge bases. Use when working on aircana's CLI, generators, knowledge-base manifests, or plugin/hook management.
---

# aircana

Project context for the aircana Ruby gem, which scaffolds and manages Claude Code plugins with Confluence/web-backed knowledge bases. Use when working on aircana's CLI, generators, knowledge-base manifests, or plugin/hook management.

## References

- [references/PRD.md](references/PRD.md) — problem statement, goals, requirements, and open questions. Read this first to understand what this project is and why it exists.
- [references/DESIGN.md](references/DESIGN.md) — architecture and implementation notes. Starts as a stub; fill in as design decisions solidify, there is no requirement to complete it up front.
- [references/ADR/](references/ADR/) — one file per architecture decision, filename-sorted chronologically. Superseded decisions are kept, not deleted — read recent files first, but don't assume an older one is wrong just because it's old.

## Recording a decision

Record any decision worth remembering as a new ADR instead of editing PRD.md or DESIGN.md in place:

```
scripts/new_adr.sh "Title of the decision"
```

Run it from anywhere under this repository; it resolves its own location and writes a timestamped file into `references/ADR/`. Fill in Context, Decision, and Consequences in the generated file, and set `Status` to `Accepted` once it's final. If this decision replaces an earlier one, add `- **Supersedes**: <old-filename>` to the new file and add a note under the old file's title pointing at the new one — never delete the old file.
