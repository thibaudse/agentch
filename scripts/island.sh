#!/bin/bash
set -euo pipefail
# island.sh - Bridge script to communicate with the AgentIsland helper app
# Usage:
#   island.sh show "message" [agent_name] [duration_secs] [pid]
#   island.sh prompt [message] [agent_name] [pid]   # interactive text input
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
        start_daemon
        wait_for_socket
    fi
    echo "$json" | nc -U "$SOCKET" -w 1 2>/dev/null
}

json_escape() {
    python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"
}

start_daemon() {
    if [ -S "$SOCKET" ]; then
        return 0
    fi

    if [ ! -f "$BINARY_PATH" ]; then
        echo "Error: AgentIsland binary not found at $BINARY_PATH" >&2
        echo "Run: cd $(dirname "$0")/.. && ./scripts/build.sh" >&2
        return 1
    fi

    LOG_FILE="/tmp/agent-island.log"
    "$BINARY_PATH" 2>>"$LOG_FILE" &
    echo $! > "$PID_FILE"
    wait_for_socket
}

wait_for_socket() {
    local retries=30
    while [ "$retries" -gt 0 ]; do
        if [ -S "$SOCKET" ]; then
            return 0
        fi
        sleep 0.1
        retries=$((retries - 1))
    done

    echo "Error: AgentIsland did not create socket at $SOCKET" >&2
    return 1
}

stop_daemon() {
    if [ -S "$SOCKET" ]; then
        send_message '{"action":"quit"}' 2>/dev/null || true
    fi

    if [ -f "$PID_FILE" ]; then
        kill "$(cat "$PID_FILE")" 2>/dev/null || true
        rm -f "$PID_FILE"
    fi

    rm -f "$SOCKET"
}

case "${1:-show}" in
    show)
        message="${2:-Hello World}"
        agent="${3:-}"
        duration="${4:-0}"
        pid="${5:-0}"
        message_json="$(json_escape "$message")"
        agent_json="$(json_escape "$agent")"
        send_message "{\"action\":\"show\",\"message\":$message_json,\"agent\":$agent_json,\"duration\":$duration,\"pid\":$pid}"
        ;;
    prompt)
        message="${2:-}"
        agent="${3:-}"
        pid="${4:-0}"
        terminal_bundle="${5:-}"
        tab_marker="${6:-}"
        tty_path="${7:-}"
        conversation="${8:-}"
        message_json="$(json_escape "$message")"
        agent_json="$(json_escape "$agent")"
        terminal_json="$(json_escape "$terminal_bundle")"
        marker_json="$(json_escape "$tab_marker")"
        tty_json="$(json_escape "$tty_path")"
        convo_json="$(json_escape "$conversation")"
        send_message "{\"action\":\"show\",\"message\":$message_json,\"agent\":$agent_json,\"duration\":0,\"pid\":$pid,\"interactive\":true,\"terminal_bundle\":$terminal_json,\"tab_marker\":$marker_json,\"tty_path\":$tty_json,\"conversation\":$convo_json}"
        ;;
    permission)
        tool="${2:-}"
        command="${3:-}"
        agent="${4:-}"
        pid="${5:-0}"
        response_pipe="${6:-}"
        suggestions="${7:-[]}"
        tool_json="$(json_escape "$tool")"
        command_json="$(json_escape "$command")"
        agent_json="$(json_escape "$agent")"
        pipe_json="$(json_escape "$response_pipe")"
        # suggestions is already JSON, inject it directly
        send_message "{\"action\":\"permission\",\"tool\":$tool_json,\"message\":$command_json,\"agent\":$agent_json,\"pid\":$pid,\"response_pipe\":$pipe_json,\"permission_suggestions\":$suggestions}"
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
        echo "Usage: island.sh {show|prompt|dismiss|start|stop} [message] [agent] [duration] [pid]" >&2
        exit 1
        ;;
esac
