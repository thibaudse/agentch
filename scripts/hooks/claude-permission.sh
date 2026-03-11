#!/bin/bash
# Claude Code PermissionRequest hook.
# - For AskUserQuestion: shows the question and options in the notch, returns the user's selection
# - For other tools: shows approve/deny buttons in the notch
# Blocks until the user decides, then returns the decision to Claude Code.

LOG="/tmp/agent-island-hook.log"
ISLAND="${AGENT_ISLAND_HOME:-$HOME/.agent-island}/scripts/island.sh"
INPUT=$(cat)

echo "$(date '+%H:%M:%S') PERMISSION INPUT(${#INPUT}b): $(echo "$INPUT" | head -c 1000)" >> "$LOG"

# Extract tool name, command, suggestions, and elicitation data
EXTRACTED=$(printf '%s' "$INPUT" | python3 -c "
import json, sys

d = json.loads(sys.stdin.read())
tool = d.get('tool_name', 'Unknown')

inp = d.get('tool_input', {})

# Check if this is an AskUserQuestion (elicitation)
is_elicitation = (tool == 'AskUserQuestion')

if is_elicitation:
    questions = inp.get('questions', [])
    if questions:
        q = questions[0]
        elicitation = {
            'question': q.get('question', ''),
            'options': q.get('options', [])
        }
    else:
        elicitation = {'question': '', 'options': []}
    command = ''
else:
    elicitation = None
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
    'suggestions': suggestions,
    'is_elicitation': is_elicitation,
    'elicitation': elicitation
}))
" 2>>"$LOG") || true

TOOL=$(printf '%s' "$EXTRACTED" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('tool','Unknown'))" 2>/dev/null) || true
IS_ELICITATION=$(printf '%s' "$EXTRACTED" | python3 -c "import json,sys; print('1' if json.loads(sys.stdin.read()).get('is_elicitation') else '0')" 2>/dev/null) || true

# Create a FIFO for the island to write the decision back
PIPE="/tmp/agent-island-perm-$$"
mkfifo "$PIPE" 2>/dev/null || true
trap 'rm -f "$PIPE"' EXIT

if [ "$IS_ELICITATION" = "1" ]; then
    # Elicitation: show the question and options
    ELICITATION_JSON=$(printf '%s' "$EXTRACTED" | python3 -c "import json,sys; print(json.dumps(json.loads(sys.stdin.read()).get('elicitation',{})))" 2>/dev/null) || true
    echo "$(date '+%H:%M:%S') ELICITATION: question=$(printf '%s' "$ELICITATION_JSON" | head -c 200) pipe=$PIPE" >> "$LOG"

    "$ISLAND" elicitation "$ELICITATION_JSON" "Claude" "$PPID" "$PIPE"

    # Block reading from the FIFO — the island writes "answer:<selection>" or "deny"
    DECISION=$(head -n1 "$PIPE" 2>/dev/null | tr -d '\n' || echo "deny")
    rm -f "$PIPE"

    echo "$(date '+%H:%M:%S') ELICITATION DECISION: $DECISION" >> "$LOG"

    if echo "$DECISION" | grep -q '^answer:'; then
        ANSWER="${DECISION#answer:}"
        echo "$(date '+%H:%M:%S') ELICITATION: user answered '$ANSWER'" >> "$LOG"
        # Deny the AskUserQuestion tool but give Claude the user's answer in the message.
        # Claude will see this and know the user's selection without the TUI dialog showing.
        OUTPUT=$(python3 -c "
import json, sys
answer = sys.argv[1]
output = {
    'hookSpecificOutput': {
        'hookEventName': 'PermissionRequest',
        'decision': {
            'behavior': 'deny',
            'message': 'The user answered via agentch notch UI. Their selection: ' + answer
        }
    }
}
print(json.dumps(output))
" "$ANSWER" 2>>"$LOG") || true
        echo "$OUTPUT"
        echo "$(date '+%H:%M:%S') ELICITATION: output deny-with-answer JSON, exiting 0" >> "$LOG"
        exit 0
    else
        echo "Elicitation dismissed by user via agentch" >&2
        echo "$(date '+%H:%M:%S') ELICITATION: dismissed via exit 2" >> "$LOG"
        exit 2
    fi
else
    # Regular permission: show approve/deny
    COMMAND=$(printf '%s' "$EXTRACTED" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('command',''))" 2>/dev/null) || true
    SUGGESTIONS=$(printf '%s' "$EXTRACTED" | python3 -c "import json,sys; print(json.dumps(json.loads(sys.stdin.read()).get('suggestions',[])))" 2>/dev/null) || true

    if [ -z "$TOOL" ]; then TOOL="Unknown"; fi
    if [ -z "$COMMAND" ]; then COMMAND="(no details)"; fi
    if [ -z "$SUGGESTIONS" ]; then SUGGESTIONS="[]"; fi

    echo "$(date '+%H:%M:%S') PERMISSION: tool=$TOOL command=$(echo "$COMMAND" | head -c 100) suggestions=$SUGGESTIONS pipe=$PIPE" >> "$LOG"

    "$ISLAND" permission "$TOOL" "$COMMAND" "Claude" "$PPID" "$PIPE" "$SUGGESTIONS"

    # Block reading from the FIFO — the island writes "allow", "deny", or "allow_always:<json>"
    DECISION=$(head -n1 "$PIPE" 2>/dev/null | tr -d '\n' || echo "deny")
    rm -f "$PIPE"

    echo "$(date '+%H:%M:%S') PERMISSION DECISION: $DECISION" >> "$LOG"

    if [ "$DECISION" = "allow" ]; then
        echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}'
        echo "$(date '+%H:%M:%S') PERMISSION: output allow JSON, exiting 0" >> "$LOG"
        exit 0
    elif echo "$DECISION" | grep -q '^allow_always:'; then
        SUGGESTION_JSON="${DECISION#allow_always:}"
        echo "$(date '+%H:%M:%S') PERMISSION: always allow with suggestion=$SUGGESTION_JSON" >> "$LOG"
        OUTPUT=$(python3 -c "
import json, sys
suggestion = json.loads(sys.argv[1])
output = {
    'hookSpecificOutput': {
        'hookEventName': 'PermissionRequest',
        'decision': {
            'behavior': 'allow',
            'updatedPermissions': [suggestion]
        }
    }
}
print(json.dumps(output))
" "$SUGGESTION_JSON" 2>>"$LOG") || true
        if [ -n "$OUTPUT" ]; then
            echo "$OUTPUT"
            echo "$(date '+%H:%M:%S') PERMISSION: output allow_always JSON, exiting 0" >> "$LOG"
            exit 0
        else
            echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}'
            echo "$(date '+%H:%M:%S') PERMISSION: fallback allow, exiting 0" >> "$LOG"
            exit 0
        fi
    else
        echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny","message":"Permission denied by user via agentch"}}}'
        echo "$(date '+%H:%M:%S') PERMISSION: output deny JSON, exiting 0" >> "$LOG"
        exit 0
    fi
fi
