#!/bin/bash
set -euo pipefail
# island.sh - Bridge script to communicate with the AgentIsland helper app
# Usage:
#   island.sh show "message" [agent_name] [duration_secs] [pid] [session_id] [session_label]
#   island.sh prompt [message] [agent_name] [pid] [terminal_bundle] [tab_marker] [tty_path] [conversation] [response_pipe] [session_id] [session_label]
#   island.sh permission [tool] [command] [agent_name] [pid] [response_pipe] [suggestions_json] [session_id] [session_label]
#   island.sh elicitation [elicitation_json] [agent_name] [pid] [response_pipe] [session_id] [session_label]
#   island.sh dismiss [session_id]
#   island.sh start   # launch the helper daemon
#   island.sh stop    # stop the helper daemon

SOCKET="/tmp/agent-island.sock"
BINARY_NAME="AgentIsland"
INSTALL_DIR="${AGENT_ISLAND_HOME:-$HOME/.agent-island}"
BINARY_PATH="$INSTALL_DIR/$BINARY_NAME"
PID_FILE="/tmp/agent-island.pid"

socket_has_listener() {
    [ -S "$SOCKET" ] || return 1
    lsof -t "$SOCKET" >/dev/null 2>&1
}

ensure_daemon_running() {
    if socket_has_listener; then
        return 0
    fi

    # Stale socket with no listener
    if [ -S "$SOCKET" ]; then
        rm -f "$SOCKET"
    fi

    # Stale pid file (or process alive without socket)
    if [ -f "$PID_FILE" ]; then
        local pid
        pid="$(cat "$PID_FILE" 2>/dev/null || true)"
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
        fi
        rm -f "$PID_FILE"
    fi

    start_daemon
}

send_message() {
    local json="$1"
    ensure_daemon_running

    if ! echo "$json" | nc -U "$SOCKET" -w 1 >/dev/null 2>&1; then
        # One retry after cleaning stale socket/daemon state
        rm -f "$SOCKET"
        rm -f "$PID_FILE"
        start_daemon
        echo "$json" | nc -U "$SOCKET" -w 1 >/dev/null 2>&1
    fi
}

json_escape() {
    python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"
}

start_daemon() {
    if socket_has_listener; then
        return 0
    fi

    if [ -S "$SOCKET" ]; then
        rm -f "$SOCKET"
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
        if socket_has_listener; then
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
        session_id="${6:-}"
        session_label="${7:-}"
        message_json="$(json_escape "$message")"
        agent_json="$(json_escape "$agent")"
        session_json="$(json_escape "$session_id")"
        session_label_json="$(json_escape "$session_label")"
        send_message "{\"action\":\"show\",\"message\":$message_json,\"agent\":$agent_json,\"duration\":$duration,\"pid\":$pid,\"session_id\":$session_json,\"session_label\":$session_label_json}"
        ;;
    prompt)
        message="${2:-}"
        agent="${3:-}"
        pid="${4:-0}"
        terminal_bundle="${5:-}"
        tab_marker="${6:-}"
        tty_path="${7:-}"
        conversation="${8:-}"
        response_pipe="${9:-}"
        session_id="${10:-}"
        session_label="${11:-}"
        message_json="$(json_escape "$message")"
        agent_json="$(json_escape "$agent")"
        terminal_json="$(json_escape "$terminal_bundle")"
        marker_json="$(json_escape "$tab_marker")"
        tty_json="$(json_escape "$tty_path")"
        convo_json="$(json_escape "$conversation")"
        pipe_json="$(json_escape "$response_pipe")"
        session_json="$(json_escape "$session_id")"
        session_label_json="$(json_escape "$session_label")"
        send_message "{\"action\":\"show\",\"message\":$message_json,\"agent\":$agent_json,\"duration\":0,\"pid\":$pid,\"interactive\":true,\"terminal_bundle\":$terminal_json,\"tab_marker\":$marker_json,\"tty_path\":$tty_json,\"conversation\":$convo_json,\"response_pipe\":$pipe_json,\"session_id\":$session_json,\"session_label\":$session_label_json}"
        ;;
    permission)
        tool="${2:-}"
        command="${3:-}"
        agent="${4:-}"
        pid="${5:-0}"
        response_pipe="${6:-}"
        suggestions="${7:-[]}"
        session_id="${8:-}"
        session_label="${9:-}"
        tool_json="$(json_escape "$tool")"
        command_json="$(json_escape "$command")"
        agent_json="$(json_escape "$agent")"
        pipe_json="$(json_escape "$response_pipe")"
        session_json="$(json_escape "$session_id")"
        session_label_json="$(json_escape "$session_label")"
        # suggestions is already JSON, inject it directly
        send_message "{\"action\":\"permission\",\"tool\":$tool_json,\"message\":$command_json,\"agent\":$agent_json,\"pid\":$pid,\"response_pipe\":$pipe_json,\"permission_suggestions\":$suggestions,\"session_id\":$session_json,\"session_label\":$session_label_json}"
        ;;
    elicitation)
        # elicitation_json is already a JSON object: {"question":"...","options":[...]}
        elicitation_json="${2:-"{}"}"
        agent="${3:-}"
        pid="${4:-0}"
        response_pipe="${5:-}"
        session_id="${6:-}"
        session_label="${7:-}"
        agent_json="$(json_escape "$agent")"
        pipe_json="$(json_escape "$response_pipe")"
        session_json="$(json_escape "$session_id")"
        session_label_json="$(json_escape "$session_label")"
        # elicitation_json is raw JSON, inject directly
        send_message "{\"action\":\"elicitation\",\"elicitation\":$elicitation_json,\"agent\":$agent_json,\"pid\":$pid,\"response_pipe\":$pipe_json,\"session_id\":$session_json,\"session_label\":$session_label_json}"
        ;;
    dismiss)
        session_id="${2:-}"
        session_json="$(json_escape "$session_id")"
        send_message "{\"action\":\"dismiss\",\"session_id\":$session_json}"
        ;;
    start)
        start_daemon
        ;;
    stop)
        stop_daemon
        ;;
    *)
        echo "Usage: island.sh {show|prompt|permission|elicitation|dismiss|start|stop} ..." >&2
        exit 1
        ;;
esac
