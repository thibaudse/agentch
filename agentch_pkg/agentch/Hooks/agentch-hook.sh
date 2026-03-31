#!/bin/bash
# agentch hook helper — captures session info and posts to the agentch server.
# Stdin: Claude hook JSON payload
# Also writes the terminal's window title to /tmp/agentch/SESSION_ID

PORT="${AGENTCH_PORT:-27182}"

# Read stdin
INPUT=$(cat)

# Extract session_id from JSON
SID=$(echo "$INPUT" | grep -o '"session_id":"[^"]*"' | head -1 | cut -d'"' -f4)
[ -z "$SID" ] && exit 0

# Get Claude's TTY
TTY=$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')

# Walk up process tree to find the terminal app PID
TPID=$PPID
for i in 1 2 3 4 5 6 7 8 9 10; do
    PARENT=$(ps -o ppid= -p $TPID 2>/dev/null | tr -d ' ')
    [ -z "$PARENT" ] || [ "$PARENT" -le 1 ] && break
    TPID=$PARENT
    # Check if this is a GUI app (has a window)
    if osascript -e "tell application \"System Events\" to return (count of windows of first process whose unix id is $TPID)" 2>/dev/null | grep -q '[1-9]'; then
        break
    fi
done

# Save the terminal's front window title to a temp file
mkdir -p /tmp/agentch
if [ -n "$TPID" ] && [ "$TPID" -gt 1 ]; then
    osascript -e "tell application \"System Events\" to return name of front window of first process whose unix id is $TPID" > "/tmp/agentch/$SID" 2>/dev/null
fi

# Post to agentch server
echo "$INPUT" | curl -s -X POST "http://localhost:$PORT/agentch?term=${TERM_PROGRAM:-}&pid=$PPID&tty=$TTY" \
    -H 'Content-Type: application/json' --data-binary @- > /dev/null 2>&1 || true
