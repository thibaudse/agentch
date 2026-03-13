#!/bin/bash
# Claude Code UserPromptSubmit hook.
# Dismisses only the notch entry for the same Claude session so
# concurrent sessions do not dismiss each other.

LOG="/tmp/agent-island-hook.log"
ISLAND="${AGENT_ISLAND_HOME:-$HOME/.agent-island}/scripts/island.sh"
INPUT=$(cat)

SESSION_ID=$(printf '%s' "$INPUT" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('session_id',''))" 2>/dev/null || true)

echo "$(date '+%H:%M:%S') USERPROMPTSUBMIT: dismiss session='$SESSION_ID'" >> "$LOG"
"$ISLAND" dismiss "$SESSION_ID" >/dev/null 2>&1 || true
exit 0
