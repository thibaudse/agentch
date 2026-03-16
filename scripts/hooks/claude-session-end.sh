#!/bin/bash
# Claude Code SessionEnd hook.
# Unregisters the session so the dot indicator is removed.

ISLAND="${AGENT_ISLAND_HOME:-$HOME/.agent-island}/scripts/island.sh"
INPUT=$(cat)

SESSION_ID=$(printf '%s' "$INPUT" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('session_id',''))" 2>/dev/null || true)

if [ -n "$SESSION_ID" ]; then
    "$ISLAND" unregister "$SESSION_ID" >/dev/null 2>&1 || true
fi
exit 0
