#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") \"Title of the decision\"" >&2
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

title="$1"
if [[ -z "$title" ]]; then
  usage
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
adr_dir="$script_dir/../references/ADR"
mkdir -p "$adr_dir"

slug="$(printf '%s' "$title" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/_/g; s/^_+//; s/_+$//')"
if [[ -z "$slug" ]]; then
  echo "error: title produces an empty slug; use at least one alphanumeric character" >&2
  exit 1
fi

timestamp="$(date +%Y%m%d%H%M%S)"
filename="${timestamp}_${slug}.md"
filepath="$adr_dir/$filename"

if [[ -e "$filepath" ]]; then
  echo "error: $filepath already exists" >&2
  exit 1
fi

cat > "$filepath" <<EOF
# ${title}

- **Status**: Proposed
- **Date**: $(date +%Y-%m-%d)

## Context

<!-- What forces are at play? What is the situation that calls for a decision? -->

## Decision

<!-- What are we doing, precisely, and why this option over the alternatives? -->

## Consequences

<!-- What becomes easier or harder as a result? What follow-up work does this create? -->
EOF

echo "$filepath"
