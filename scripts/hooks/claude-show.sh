#!/bin/bash
# Claude Code Stop hook (synchronous/blocking).
# 1. Reads the transcript to get the full conversation
# 2. Uses last_assistant_message from hook input (always fresh)
# 3. Shows the interactive island prompt
# 4. Blocks on FIFO waiting for user response
# 5. Returns decision:block with reason to send text back to Claude, or exits 0 to stop

LOG="/tmp/agent-island-hook.log"
ISLAND="${AGENT_ISLAND_HOME:-$HOME/.agent-island}/scripts/island.sh"
CHECK_UPDATE="${AGENT_ISLAND_HOME:-$HOME/.agent-island}/scripts/check-update.sh"
INPUT=$(cat)

# Check for updates in the background (non-blocking, once per day via cache)
check_for_update() {
    if [ -x "$CHECK_UPDATE" ]; then
        local latest
        latest="$("$CHECK_UPDATE" 2>/dev/null)" || true
        if [ -n "$latest" ]; then
            "$ISLAND" show "agentch v${latest} available — run \`brew upgrade agentch\`" "agentch" 8 0 "" "" >/dev/null 2>&1 || true
        fi
    fi
}
check_for_update &
SESSION_ID=$(printf '%s' "$INPUT" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('session_id',''))" 2>/dev/null || true)
CWD=$(printf '%s' "$INPUT" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('cwd',''))" 2>/dev/null || true)

resolve_branch_label() {
    local cwd="$1"
    [ -n "$cwd" ] || return 0

    local label
    label="$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    if [ -z "$label" ] || [ "$label" = "HEAD" ]; then
        label="$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null || true)"
    fi

    if [ -n "$label" ]; then
        printf '%s' "$label"
    fi
}

BRANCH_LABEL="$(resolve_branch_label "$CWD")"

read_fifo_line_with_timeout() {
    local fifo_path="$1"
    local timeout_secs="$2"

    python3 - "$fifo_path" "$timeout_secs" <<'PY'
import os
import select
import sys
import time

path = sys.argv[1]
try:
    timeout = float(sys.argv[2])
except Exception:
    timeout = 0.0

deadline = time.monotonic() + max(timeout, 0.0)
fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)

try:
    while True:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            sys.exit(1)

        ready, _, _ = select.select([fd], [], [], remaining)
        if not ready:
            sys.exit(1)

        chunk = os.read(fd, 4096)
        if not chunk:
            time.sleep(0.01)
            continue

        line = chunk.decode("utf-8", "ignore").splitlines()
        if line:
            print(line[0])
            sys.exit(0)
finally:
    os.close(fd)
PY
}

echo "$(date '+%H:%M:%S') STOP HOOK INPUT: $(echo "$INPUT" | head -c 500)" >> "$LOG"

# Note: we intentionally do NOT check stop_hook_active here.
# The loop is user-driven — it only continues when the user types a response
# in the island. The natural exit is the user dismissing (or closing) the island,
# which makes the hook exit 0 and Claude stops normally.

# Extract message + conversation from hook input and transcript.
EXTRACT=$(printf '%s' "$INPUT" | python3 -c "
import json, sys, time, re

input_data = json.loads(sys.stdin.read())
transcript = input_data.get('transcript_path', '')

# The hook input has the latest message directly — always prefer this
last_msg = input_data.get('last_assistant_message', '')

# For Stop hooks without last_assistant_message, wait for transcript flush
hook_event = input_data.get('hook_event_name', '')
if not last_msg and hook_event == 'Stop' and transcript:
    time.sleep(1.0)

if not transcript and not last_msg:
    sys.exit(0)

if not transcript:
    print(json.dumps({'message': last_msg, 'conversation': ''}))
    sys.exit(0)

# Read all transcript entries
all_entries = []
with open(transcript) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            all_entries.append(json.loads(line))
        except json.JSONDecodeError:
            continue

# Extract text from a message content field (handles both list-of-blocks and plain string)
def extract_text(message):
    if isinstance(message, str):
        return message.strip()
    content = message.get('content', []) if isinstance(message, dict) else []
    if isinstance(content, str):
        return content.strip()
    parts = []
    for block in content:
        if isinstance(block, dict) and block.get('type') == 'text':
            parts.append(block['text'].strip())
        elif isinstance(block, str):
            parts.append(block.strip())
    return '\n\n'.join(parts)

# Check last assistant entry has text (not mid-turn tool_use only)
assistant_entries = [e for e in all_entries if e.get('type') == 'assistant']
if not last_msg:
    if not assistant_entries:
        sys.exit(0)
    last_content = assistant_entries[-1].get('message', {}).get('content', [])
    if isinstance(last_content, str):
        last_msg = last_content
    else:
        text_blocks = [b for b in last_content
                       if (isinstance(b, dict) and b.get('type') == 'text') or isinstance(b, str)]
        if not text_blocks:
            sys.exit(0)  # Mid-turn: only tool_use blocks
        last_msg = extract_text(assistant_entries[-1].get('message', {}))

# Build conversation from all user + assistant entries
conversation_parts = []
for entry in all_entries:
    entry_type = entry.get('type', '')
    msg = entry.get('message', {})

    if entry_type in ('human', 'user'):
        text = extract_text(msg)
        if text:
            text = re.sub(r'^(\[?Stop hook feedback\]?[:\s]*)', '', text, flags=re.IGNORECASE).strip()
        if text:
            conversation_parts.append('**You:** ' + text)
    elif entry_type == 'assistant':
        text = extract_text(msg)
        if text:
            conversation_parts.append('**Claude:** ' + text)

# The Stop hook fires before the transcript is flushed, so the last assistant
# message may not be in the transcript yet. Append it if missing.
if last_msg:
    last_claude_entry = '**Claude:** ' + last_msg.strip()
    if not conversation_parts or conversation_parts[-1] != last_claude_entry:
        conversation_parts.append(last_claude_entry)

result = {
    'message': last_msg.strip(),
    'conversation': '\n\n'.join(conversation_parts) if conversation_parts else ''
}
print(json.dumps(result))
" 2>>"$LOG") || true

echo "$(date '+%H:%M:%S') STOP EXTRACT: $(echo "$EXTRACT" | head -c 300)" >> "$LOG"

# Parse the JSON result
if [ -n "$EXTRACT" ]; then
    MSG=$(printf '%s' "$EXTRACT" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('message',''))" 2>/dev/null) || true
    CONVO=$(printf '%s' "$EXTRACT" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('conversation',''))" 2>/dev/null) || true
fi

if [ -z "$MSG" ]; then
    MSG="Done"
fi

# Create FIFO for the island to write the user's response back
RESPONSE_PIPE="/tmp/agent-island-response-$$"
mkfifo "$RESPONSE_PIPE" 2>/dev/null || true
trap 'rm -f "$RESPONSE_PIPE"' EXIT

STOP_TIMEOUT_SECS="${AGENTCH_STOP_TIMEOUT_SECS:-590}"
if ! [[ "$STOP_TIMEOUT_SECS" =~ ^[0-9]+$ ]]; then
    STOP_TIMEOUT_SECS=590
fi

dismiss_notch_on_signal() {
    echo "$(date '+%H:%M:%S') STOP: received termination signal, dismissing session '$SESSION_ID'" >> "$LOG"
    "$ISLAND" dismiss "$SESSION_ID" >/dev/null 2>&1 || true
    exit 0
}

trap dismiss_notch_on_signal TERM INT HUP

# Dismiss any stale permission/elicitation prompt for this session
# (e.g. if the user answered a permission in the terminal, the notch is still showing it)
"$ISLAND" dismiss "$SESSION_ID" >/dev/null 2>&1 || true

# Show interactive island prompt (no terminal info needed — we use decision:block)
"$ISLAND" prompt "$MSG" "Claude" "$PPID" "" "" "" "$CONVO" "$RESPONSE_PIPE" "$SESSION_ID" "$BRANCH_LABEL"

# Block reading from the FIFO — the island writes the user's text or "__dismiss__"
if RESPONSE="$(read_fifo_line_with_timeout "$RESPONSE_PIPE" "$STOP_TIMEOUT_SECS")"; then
    RESPONSE=$(printf '%s' "$RESPONSE" | tr -d '\n')
else
    RESPONSE="__dismiss__"
    echo "$(date '+%H:%M:%S') STOP: timed out after ${STOP_TIMEOUT_SECS}s, dismissing session '$SESSION_ID'" >> "$LOG"
    "$ISLAND" dismiss "$SESSION_ID" >/dev/null 2>&1 || true
fi
rm -f "$RESPONSE_PIPE"

echo "$(date '+%H:%M:%S') STOP RESPONSE: '$RESPONSE'" >> "$LOG"

if [ -z "$RESPONSE" ] || [ "$RESPONSE" = "__dismiss__" ]; then
    # User dismissed the island — let Claude stop normally
    echo "$(date '+%H:%M:%S') STOP: dismissed, exiting 0 (no output)" >> "$LOG"
    exit 0
fi

# User provided text — return decision:block to send it back to Claude as feedback
OUTPUT=$(python3 -c "
import json, sys
text = sys.argv[1]
output = {
    'decision': 'block',
    'reason': text
}
print(json.dumps(output))
" "$RESPONSE" 2>>"$LOG") || true

echo "$OUTPUT"
echo "$(date '+%H:%M:%S') STOP: output decision:block, exiting 0" >> "$LOG"
exit 0
