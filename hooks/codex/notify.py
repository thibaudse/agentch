#!/usr/bin/env python3
"""
Codex CLI notify hook for agentch.

Configure in ~/.codex/config.toml:
    notify = ["python3", "<path-to>/agent-island/hooks/codex/notify.py"]

When the agent completes a turn (and is waiting for input), this script
sends a message to the agentch helper app.
"""
import json
import os
import socket
import sys

SOCKET_PATH = "/tmp/agent-island.sock"

def send_to_island(action: str, message: str = "", agent: str = "Codex", duration: float = 0, pid: int = 0, interactive: bool = False):
    payload = json.dumps({
        "action": action,
        "message": message,
        "agent": agent,
        "duration": duration,
        "pid": pid,
        "interactive": interactive,
    })
    try:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.settimeout(2)
        sock.connect(SOCKET_PATH)
        sock.sendall((payload + "\n").encode())
        sock.recv(64)
        sock.close()
    except Exception:
        pass  # Silently fail if island helper isn't running

def main():
    # Codex passes a JSON argument to the notify script
    if len(sys.argv) < 2:
        return

    try:
        event = json.loads(sys.argv[1])
    except (json.JSONDecodeError, IndexError):
        return

    event_type = event.get("type", "")

    if event_type == "agent-turn-complete":
        send_to_island("show", "Your turn", "Codex", pid=os.getppid(), interactive=True)

if __name__ == "__main__":
    main()
