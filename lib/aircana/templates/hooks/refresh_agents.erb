#!/bin/bash

# Auto-refresh agent knowledge bases on session start
# Runs at most once per 24 hours to avoid API rate limits

set -e

# Create log directory if it doesn't exist
mkdir -p ~/.aircana
LOG_FILE="$HOME/.aircana/hooks.log"

# Claude Code provides this environment variable
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT}"

if [ -z "$PLUGIN_ROOT" ]; then
    echo "$(date): Warning - CLAUDE_PLUGIN_ROOT not set, skipping agent refresh" >> "$LOG_FILE"
    echo "{}"
    exit 0
fi

TIMESTAMP_FILE="${PLUGIN_ROOT}/.last_refresh"
REFRESH_INTERVAL_SECONDS=86400  # 24 hours

# Check if we've refreshed recently
if [ -f "$TIMESTAMP_FILE" ]; then
    LAST_REFRESH=$(cat "$TIMESTAMP_FILE")
    CURRENT_TIME=$(date +%s)
    TIME_DIFF=$((CURRENT_TIME - LAST_REFRESH))

    if [ $TIME_DIFF -lt $REFRESH_INTERVAL_SECONDS ]; then
        HOURS_SINCE=$((TIME_DIFF / 3600))
        echo "$(date): Agent knowledge refreshed ${HOURS_SINCE}h ago, skipping refresh" >> "$LOG_FILE"
        echo "{}"
        exit 0
    fi
fi

# Tell aircana where the plugin lives
export AIRCANA_PLUGIN_ROOT="$PLUGIN_ROOT"

echo "$(date): Starting agent knowledge refresh from plugin root: $PLUGIN_ROOT" >> "$LOG_FILE"

# Refresh all agents (capture output to log)
if aircana agents refresh-all >> "$LOG_FILE" 2>&1; then
    # Update timestamp on success
    date +%s > "$TIMESTAMP_FILE"
    echo "$(date): Agent knowledge refresh completed successfully" >> "$LOG_FILE"

    # Return success with context
    CONTEXT="Agent knowledge bases refreshed successfully"
    ESCAPED_CONTEXT=$(echo -n "$CONTEXT" | sed 's/"/\\"/g')
    cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "$ESCAPED_CONTEXT"
  }
}
EOF
else
    echo "$(date): Warning - Agent refresh failed, will retry next session" >> "$LOG_FILE"
    # Don't update timestamp so we retry next time
    # Don't fail the session start
    echo "{}"
    exit 0
fi
