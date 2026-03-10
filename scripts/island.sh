#!/bin/bash
# island.sh - Bridge script to communicate with the AgentIsland helper app
# Usage:
#   island.sh show "message" [agent_name] [duration_secs]
#   island.sh dismiss
#   island.sh start   # launch the helper daemon
#   island.sh stop    # stop the helper daemon

SOCKET="/tmp/agent-island.sock"
BINARY_NAME="AgentIsland"
INSTALL_DIR="${AGENT_ISLAND_HOME:-$HOME/.agent-island}"
BINARY_PATH="$INSTALL_DIR/$BINARY_NAME"
PID_FILE="/tmp/agent-island.pid"

send_message() {
    local json="$1"
    if [ ! -S "$SOCKET" ]; then
        # Auto-start the daemon if not running
        start_daemon
        sleep 0.5
    fi
    echo "$json" | nc -U "$SOCKET" -w 1 2>/dev/null
}

start_daemon() {
    if [ -S "$SOCKET" ] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null; then
        return 0  # Already running
    fi
    if [ ! -f "$BINARY_PATH" ]; then
        echo "Error: AgentIsland binary not found at $BINARY_PATH" >&2
        echo "Run: cd $(dirname "$0")/.. && ./scripts/build.sh" >&2
        return 1
    fi
    "$BINARY_PATH" &
    echo $! > "$PID_FILE"
    sleep 0.3  # Give it time to start
}

stop_daemon() {
    send_message '{"action":"quit"}' 2>/dev/null
    if [ -f "$PID_FILE" ]; then
        kill "$(cat "$PID_FILE")" 2>/dev/null
        rm -f "$PID_FILE"
    fi
    rm -f "$SOCKET"
}

case "${1:-show}" in
    show)
        message="${2:-Hello World}"
        agent="${3:-}"
        duration="${4:-0}"
        send_message "{\"action\":\"show\",\"message\":\"$message\",\"agent\":\"$agent\",\"duration\":$duration}"
        ;;
    dismiss)
        send_message '{"action":"dismiss"}'
        ;;
    start)
        start_daemon
        ;;
    stop)
        stop_daemon
        ;;
    *)
        echo "Usage: island.sh {show|dismiss|start|stop} [message] [agent] [duration]" >&2
        exit 1
        ;;
esac
