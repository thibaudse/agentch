#!/bin/bash
set -euo pipefail
# Claude Code Stop/Notification hook.
# 1. Reads the transcript to get Claude's last message
# 2. Detects the terminal app via TERM_PROGRAM
# 3. Shows the interactive island prompt

ISLAND="${AGENT_ISLAND_HOME:-$HOME/.agent-island}/scripts/island.sh"
INPUT=$(cat)

# Get the TTY of the Claude Code process (our parent).
# `tty` won't work here because Claude pipes stdin to hooks.
# Instead, look up the TTY via ps on the parent PID.
TTY_DEV=$(ps -o tty= -p "$PPID" 2>/dev/null | tr -d ' ')
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

# Extract last assistant message from transcript
MSG=$(echo "$INPUT" | python3 -c "
import json, sys, re

try:
    input_data = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)

transcript = input_data.get('transcript_path', '')
if not transcript:
    sys.exit(0)

last_text = ''
try:
    with open(transcript) as f:
        for line in f:
            try:
                entry = json.loads(line)
                if entry.get('type') == 'assistant':
                    content = entry.get('message', {}).get('content', [])
                    for block in content:
                        if isinstance(block, dict) and block.get('type') == 'text':
                            last_text = block['text']
                        elif isinstance(block, str):
                            last_text = block
            except (json.JSONDecodeError, KeyError):
                pass
except Exception:
    pass

# Build a concise summary: take the first meaningful sentence/line
lines = [l.strip() for l in last_text.strip().split('\n') if l.strip()]
# Skip markdown noise: code fences, dividers, headings, list markers, blank-ish
skip = re.compile(r'^(\`\`\`|---|===|#{1,6}\s|!\[)')
lines = [l for l in lines if not skip.match(l)]

# Strip leading markdown artifacts (bullets, bold markers, etc.)
cleaned = []
for l in lines:
    l = re.sub(r'^[\-\*>]+\s*', '', l)
    l = re.sub(r'\*\*(.+?)\*\*', r'\1', l)  # remove bold
    l = re.sub(r'\*(.+?)\*', r'\1', l)        # remove italic
    l = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', l)  # links -> text
    l = l.strip()
    if l:
        cleaned.append(l)

# Pick the first meaningful line (usually the opening sentence / summary)
summary = cleaned[0] if cleaned else ''

# Truncate for the notch display
if len(summary) > 60:
    summary = summary[:57] + '...'

print(summary)
" 2>/dev/null)

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

exec "$ISLAND" prompt "$MSG" "Claude" "$PPID" "$TERM_BUNDLE" "$TAB_MARKER" "$TTY_PATH"
