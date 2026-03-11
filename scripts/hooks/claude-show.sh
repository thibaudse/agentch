#!/bin/bash
# Claude Code Stop/Notification hook.
# 1. Reads the transcript to get the full conversation
# 2. Uses last_assistant_message from hook input (always fresh)
# 3. Detects the terminal app via TERM_PROGRAM
# 4. Shows the interactive island prompt

LOG="/tmp/agent-island-hook.log"
ISLAND="${AGENT_ISLAND_HOME:-$HOME/.agent-island}/scripts/island.sh"
INPUT=$(cat)

echo "$(date '+%H:%M:%S') RAW INPUT: $(echo "$INPUT" | head -c 500)" >> "$LOG"

# Get the TTY of the Claude Code process (our parent).
# `tty` won't work here because Claude pipes stdin to hooks.
TTY_DEV=$(ps -o tty= -p "$PPID" 2>/dev/null | tr -d ' ' || true)
if [ -n "$TTY_DEV" ] && [ "$TTY_DEV" != "??" ]; then
    TTY_PATH="/dev/$TTY_DEV"
else
    TTY_PATH=""
fi

# Generate a unique marker and tag this terminal tab so the island can find it.
TAB_MARKER="ai-$$-$(date +%s)"
if [ -n "$TTY_PATH" ] && [ -w "$TTY_PATH" ]; then
    printf '\033]2;%s\007' "$TAB_MARKER" > "$TTY_PATH"
fi

# Extract message + conversation from hook input and transcript.
EXTRACT=$(printf '%s' "$INPUT" | python3 -c "
import json, sys, time

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
            conversation_parts.append('**You:** ' + text)
    elif entry_type == 'assistant':
        text = extract_text(msg)
        if text:
            conversation_parts.append('**Claude:** ' + text)

result = {
    'message': last_msg.strip(),
    'conversation': '\n\n'.join(conversation_parts) if conversation_parts else ''
}
print(json.dumps(result))
" 2>>"$LOG") || true

echo "$(date '+%H:%M:%S') EXTRACT: $(echo "$EXTRACT" | head -c 300)" >> "$LOG"

# Parse the JSON result
if [ -n "$EXTRACT" ]; then
    MSG=$(printf '%s' "$EXTRACT" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('message',''))" 2>/dev/null) || true
    CONVO=$(printf '%s' "$EXTRACT" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('conversation',''))" 2>/dev/null) || true
fi

if [ -z "$MSG" ]; then
    MSG="Done"
fi

# Map TERM_PROGRAM to macOS bundle identifier
TERM_BUNDLE=""
case "${TERM_PROGRAM:-}" in
    Apple_Terminal) TERM_BUNDLE="com.apple.Terminal" ;;
    iTerm.app)     TERM_BUNDLE="com.googlecode.iterm2" ;;
    ghostty)       TERM_BUNDLE="com.mitchellh.ghostty" ;;
    WezTerm)       TERM_BUNDLE="com.github.wez.wezterm" ;;
    Alacritty)     TERM_BUNDLE="org.alacritty" ;;
    kitty)         TERM_BUNDLE="net.kovidgoyal.kitty" ;;
esac

exec "$ISLAND" prompt "$MSG" "Claude" "$PPID" "$TERM_BUNDLE" "$TAB_MARKER" "$TTY_PATH" "$CONVO"
