#!/bin/bash
# Claude Code SessionStart hook.
# Registers the session so the notch shows a dot indicator.

ISLAND="${AGENT_ISLAND_HOME:-$HOME/.agent-island}/scripts/island.sh"
INPUT=$(cat)

SESSION_ID=$(printf '%s' "$INPUT" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('session_id',''))" 2>/dev/null || true)
CWD=$(printf '%s' "$INPUT" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('cwd',''))" 2>/dev/null || true)

LABEL=""
if [ -n "$CWD" ]; then
    LABEL="$(git -C "$CWD" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    [ "$LABEL" = "HEAD" ] && LABEL="$(git -C "$CWD" rev-parse --short HEAD 2>/dev/null || true)"
fi

if [ -n "$SESSION_ID" ]; then
    "$ISLAND" register "$SESSION_ID" "$LABEL" >/dev/null 2>&1 || true
fi
exit 0
