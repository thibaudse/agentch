#!/bin/bash
# Claude Code SessionStart hook.
# Registers the session so the notch shows a dot indicator.

ISLAND="${AGENT_ISLAND_HOME:-$HOME/.agent-island}/scripts/island.sh"
INPUT=$(cat)

SESSION_ID=$(printf '%s' "$INPUT" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('session_id',''))" 2>/dev/null || true)

if [ -n "$SESSION_ID" ]; then
    "$ISLAND" register "$SESSION_ID" >/dev/null 2>&1 || true
fi
exit 0
