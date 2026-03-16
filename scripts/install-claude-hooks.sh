#!/bin/bash
set -euo pipefail

AGENT_HOME="${AGENT_ISLAND_HOME:-$HOME/.agent-island}"
SETTINGS_PATH="$HOME/.claude/settings.json"

resolve_cmd() {
    local wrapper="$1"
    local fallback="$2"
    if command -v "$wrapper" >/dev/null 2>&1; then
        printf '%s' "$wrapper"
        return
    fi
    printf '%s' "$fallback"
}

SHOW_CMD="$(resolve_cmd "agentch-claude-show" "$AGENT_HOME/scripts/hooks/claude-show.sh")"
PERMISSION_CMD="$(resolve_cmd "agentch-claude-permission" "$AGENT_HOME/scripts/hooks/claude-permission.sh")"
DISMISS_CMD="$(resolve_cmd "agentch-claude-dismiss" "$AGENT_HOME/scripts/hooks/claude-dismiss.sh")"
SESSION_START_CMD="$(resolve_cmd "agentch-claude-session-start" "$AGENT_HOME/scripts/hooks/claude-session-start.sh")"
SESSION_END_CMD="$(resolve_cmd "agentch-claude-session-end" "$AGENT_HOME/scripts/hooks/claude-session-end.sh")"

mkdir -p "$HOME/.claude"

python3 - "$SETTINGS_PATH" "$SHOW_CMD" "$PERMISSION_CMD" "$DISMISS_CMD" "$SESSION_START_CMD" "$SESSION_END_CMD" <<'PY'
import json
import pathlib
import sys

settings_path = pathlib.Path(sys.argv[1]).expanduser()
show_cmd = sys.argv[2]
permission_cmd = sys.argv[3]
dismiss_cmd = sys.argv[4]
session_start_cmd = sys.argv[5]
session_end_cmd = sys.argv[6]

if settings_path.exists():
    try:
        settings = json.loads(settings_path.read_text())
    except json.JSONDecodeError:
        settings = {}
else:
    settings = {}

hooks = settings.get("hooks", {})

agentch_events = {
    "SessionStart": [
        {
            "hooks": [
                {
                    "type": "command",
                    "command": session_start_cmd,
                    "async": True,
                    "timeout": 5,
                }
            ]
        }
    ],
    "SessionEnd": [
        {
            "hooks": [
                {
                    "type": "command",
                    "command": session_end_cmd,
                    "async": True,
                    "timeout": 5,
                }
            ]
        }
    ],
    "Stop": [
        {
            "hooks": [
                {
                    "type": "command",
                    "command": show_cmd,
                    "timeout": 600,
                }
            ]
        }
    ],
    "PermissionRequest": [
        {
            "hooks": [
                {
                    "type": "command",
                    "command": permission_cmd,
                    "timeout": 120,
                }
            ]
        }
    ],
    "UserPromptSubmit": [
        {
            "hooks": [
                {
                    "type": "command",
                    "command": dismiss_cmd,
                    "async": True,
                    "timeout": 5,
                }
            ]
        }
    ],
}

def is_agentch_command(command: str) -> bool:
    markers = [
        "agentch-claude-show",
        "agentch-claude-permission",
        "agentch-claude-dismiss",
        "agentch-claude-session-start",
        "agentch-claude-session-end",
        "/scripts/hooks/claude-show.sh",
        "/scripts/hooks/claude-permission.sh",
        "/scripts/hooks/claude-dismiss.sh",
        "/scripts/hooks/claude-session-start.sh",
        "/scripts/hooks/claude-session-end.sh",
    ]
    return any(marker in command for marker in markers)

for event, entries in agentch_events.items():
    cleaned_entries = []
    for entry in hooks.get(event, []):
        commands = [h.get("command", "") for h in entry.get("hooks", [])]
        if any(is_agentch_command(command) for command in commands):
            continue
        cleaned_entries.append(entry)
    hooks[event] = cleaned_entries + entries

settings["hooks"] = hooks
settings_path.write_text(json.dumps(settings, indent=2) + "\n")

print(f"Updated {settings_path}")
print("Configured agentch hooks:")
print(f"  SessionStart -> {session_start_cmd}")
print(f"  SessionEnd -> {session_end_cmd}")
print(f"  Stop -> {show_cmd}")
print(f"  PermissionRequest -> {permission_cmd}")
print(f"  UserPromptSubmit -> {dismiss_cmd}")
PY

echo "Done. Restart Claude for hook changes to apply."
