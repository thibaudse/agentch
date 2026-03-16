#!/bin/bash
set -euo pipefail
# check-update.sh - Check GitHub for newer agentch releases (cached, once per day)
# Returns the latest version on stdout if an update is available, empty otherwise.
# Uses a cache file to avoid hitting the API on every session.

INSTALL_DIR="${AGENT_ISLAND_HOME:-$HOME/.agent-island}"
BINARY_PATH="$INSTALL_DIR/AgentIsland"
CACHE_DIR="$INSTALL_DIR/cache"
CACHE_FILE="$CACHE_DIR/latest-version"
CACHE_MAX_AGE=86400  # 24 hours in seconds
REPO="thibaudse/agentch"

get_local_version() {
    if [ -f "$BINARY_PATH" ]; then
        "$BINARY_PATH" --version 2>/dev/null || true
    fi
}

is_cache_fresh() {
    [ -f "$CACHE_FILE" ] || return 1

    local now file_age age
    now=$(date +%s)
    file_age=$(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)
    age=$((now - file_age))
    [ "$age" -lt "$CACHE_MAX_AGE" ]
}

fetch_latest_version() {
    mkdir -p "$CACHE_DIR"

    local latest
    latest=$(curl -fsSL --max-time 5 \
        "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null \
        | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('tag_name','').lstrip('v'))" 2>/dev/null) || true

    if [ -n "$latest" ]; then
        printf '%s' "$latest" > "$CACHE_FILE"
        printf '%s' "$latest"
    fi
}

get_cached_version() {
    cat "$CACHE_FILE" 2>/dev/null || true
}

# Compare two semver strings. Returns 0 if $1 < $2 (update available).
version_lt() {
    [ "$1" = "$2" ] && return 1
    local IFS=.
    local i a=($1) b=($2)
    for ((i=0; i<${#b[@]}; i++)); do
        local va=${a[i]:-0}
        local vb=${b[i]:-0}
        if ((va < vb)); then return 0; fi
        if ((va > vb)); then return 1; fi
    done
    return 1
}

# --- Main ---

local_version="$(get_local_version)"
[ -n "$local_version" ] || exit 0

if is_cache_fresh; then
    latest="$(get_cached_version)"
else
    latest="$(fetch_latest_version)"
fi

[ -n "$latest" ] || exit 0

if version_lt "$local_version" "$latest"; then
    echo "$latest"
fi
