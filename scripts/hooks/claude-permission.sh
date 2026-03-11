#!/bin/bash
# Claude Code PermissionRequest hook.
# Shows the tool + command in the notch with approve/deny buttons.
# Blocks until the user decides, then returns the decision to Claude Code.

LOG="/tmp/agent-island-hook.log"
ISLAND="${AGENT_ISLAND_HOME:-$HOME/.agent-island}/scripts/island.sh"
INPUT=$(cat)

echo "$(date '+%H:%M:%S') PERMISSION INPUT(${#INPUT}b): $(echo "$INPUT" | head -c 1000)" >> "$LOG"

# Extract tool name, command, and permission suggestions from the hook input
EXTRACTED=$(printf '%s' "$INPUT" | python3 -c "
import json, sys

d = json.loads(sys.stdin.read())
tool = d.get('tool_name', 'Unknown')

inp = d.get('tool_input', {})
if isinstance(inp, dict):
    if 'command' in inp:
        command = inp['command']
    elif 'file_path' in inp:
        command = inp['file_path']
    else:
        command = json.dumps(inp, indent=2)
else:
    command = str(inp)

suggestions = d.get('permission_suggestions', [])

print(json.dumps({
    'tool': tool,
    'command': command,
    'suggestions': suggestions
}))
" 2>>"$LOG") || true

TOOL=$(printf '%s' "$EXTRACTED" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('tool','Unknown'))" 2>/dev/null) || true
COMMAND=$(printf '%s' "$EXTRACTED" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('command',''))" 2>/dev/null) || true
SUGGESTIONS=$(printf '%s' "$EXTRACTED" | python3 -c "import json,sys; print(json.dumps(json.loads(sys.stdin.read()).get('suggestions',[])))" 2>/dev/null) || true

if [ -z "$TOOL" ]; then TOOL="Unknown"; fi
if [ -z "$COMMAND" ]; then COMMAND="(no details)"; fi
if [ -z "$SUGGESTIONS" ]; then SUGGESTIONS="[]"; fi

# Create a FIFO for the island to write the decision back
PIPE="/tmp/agent-island-perm-$$"
mkfifo "$PIPE" 2>/dev/null || true
trap 'rm -f "$PIPE"' EXIT

echo "$(date '+%H:%M:%S') PERMISSION: tool=$TOOL command=$(echo "$COMMAND" | head -c 100) suggestions=$SUGGESTIONS pipe=$PIPE" >> "$LOG"

# Show the permission prompt in the island (with suggestions)
"$ISLAND" permission "$TOOL" "$COMMAND" "Claude" "$PPID" "$PIPE" "$SUGGESTIONS"

# Block reading from the FIFO — the island writes "allow", "deny", or "allow_always:<json>"
DECISION=$(head -n1 "$PIPE" 2>/dev/null | tr -d '\n' || echo "deny")
rm -f "$PIPE"

echo "$(date '+%H:%M:%S') PERMISSION DECISION: $DECISION" >> "$LOG"

if [ "$DECISION" = "allow" ]; then
    # Simple allow — no rule changes
    echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}'
    echo "$(date '+%H:%M:%S') PERMISSION: output allow JSON, exiting 0" >> "$LOG"
    exit 0
elif echo "$DECISION" | grep -q '^allow_always:'; then
    # Allow + apply the "always allow" suggestion as updatedPermissions
    SUGGESTION_JSON="${DECISION#allow_always:}"
    echo "$(date '+%H:%M:%S') PERMISSION: always allow with suggestion=$SUGGESTION_JSON" >> "$LOG"
    # Build the output JSON with updatedPermissions
    OUTPUT=$(python3 -c "
import json, sys
suggestion = json.loads(sys.argv[1])
output = {
    'hookSpecificOutput': {
        'hookEventName': 'PermissionRequest',
        'decision': {
            'behavior': 'allow',
            'updatedPermissions': suggestion
        }
    }
}
print(json.dumps(output))
" "$SUGGESTION_JSON" 2>>"$LOG") || true
    if [ -n "$OUTPUT" ]; then
        echo "$OUTPUT"
        echo "$(date '+%H:%M:%S') PERMISSION: output allow_always JSON=$OUTPUT, exiting 0" >> "$LOG"
        exit 0
    else
        # Fallback: just allow without the rule
        echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}'
        echo "$(date '+%H:%M:%S') PERMISSION: fallback allow (suggestion parse failed), exiting 0" >> "$LOG"
        exit 0
    fi
else
    # Exit 2 to deny — Claude Code treats exit 2 as a blocking denial
    echo "Permission denied by user via Agent Island" >&2
    echo "$(date '+%H:%M:%S') PERMISSION: denied via exit 2" >> "$LOG"
    exit 2
fi
