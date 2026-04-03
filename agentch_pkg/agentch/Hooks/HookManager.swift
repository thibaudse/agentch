import Foundation

/// Supported agent types and their hook configurations.
enum AgentHookConfig {
    case claude
    case codex

    var settingsPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        switch self {
        case .claude: return "\(home)/.claude/settings.json"
        case .codex:  return "\(home)/.codex/hooks.json"
        }
    }

    var hookEvents: [String] {
        switch self {
        case .claude:
            return ["SessionStart", "SessionEnd", "PreToolUse", "PostToolUse",
                    "Stop", "UserPromptSubmit", "PermissionRequest", "Elicitation"]
        case .codex:
            return ["SessionStart", "PreToolUse", "PostToolUse",
                    "Stop", "UserPromptSubmit"]
        }
    }

    /// Events required to check if hooks are "installed"
    var requiredEvents: [String] {
        switch self {
        case .claude:
            return ["SessionStart", "SessionEnd", "PreToolUse", "PostToolUse",
                    "Stop", "UserPromptSubmit", "PermissionRequest", "Elicitation"]
        case .codex:
            return ["SessionStart", "PreToolUse", "PostToolUse",
                    "Stop", "UserPromptSubmit"]
        }
    }

    var label: String {
        switch self {
        case .claude: return "Claude"
        case .codex:  return "Codex"
        }
    }

    static let all: [AgentHookConfig] = [.claude, .codex]
}

struct HookManager {
    static let hookIdentifier = "agentch"

    static var hookScriptPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.agentch/hook.sh"
    }

    private static func hookCommand(port: UInt16) -> String {
        "AGENTCH_PORT=\(port) /bin/bash \(hookScriptPath)"
    }

    static func installScript() {
        let scriptContent = """
        #!/bin/bash
        export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH"
        PORT="${AGENTCH_PORT:-27182}"
        INPUT=$(cat)
        SID=$(echo "$INPUT" | grep -o '"session_id":"[^"]*"' | head -1 | cut -d'"' -f4)
        [ -z "$SID" ] && exit 0
        TTY=$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')
        EVENT=$(echo "$INPUT" | grep -o '"hook_event_name":"[^"]*"' | head -1 | cut -d'"' -f4)

        # Save terminal window title for tab matching and session name
        mkdir -p /tmp/agentch
        if [ -n "$TERM_PROGRAM" ]; then
            case "$TERM_PROGRAM" in
                ghostty)         APP_NAME="Ghostty" ;;
                Apple_Terminal)  APP_NAME="Terminal" ;;
                iTerm.app)       APP_NAME="iTerm2" ;;
                WarpTerminal)    APP_NAME="Warp" ;;
                *)               APP_NAME="$TERM_PROGRAM" ;;
            esac
            /usr/bin/osascript -e "tell application \\"$APP_NAME\\" to return name of front window" \\
                > "/tmp/agentch/$SID" 2>/dev/null
        fi

        if [ "$EVENT" = "PermissionRequest" ] || [ "$EVENT" = "Elicitation" ]; then
            # Block and return decision for Claude to read
            RESPONSE=$(echo "$INPUT" | /usr/bin/curl -s -X POST "http://localhost:$PORT/agentch/decision?term=${TERM_PROGRAM:-}&pid=$PPID&tty=$TTY" \\
                -H 'Content-Type: application/json' --data-binary @- 2>/dev/null)
            [ -n "$RESPONSE" ] && echo "$RESPONSE"
        else
            # Fire-and-forget for all other events
            echo "$INPUT" | /usr/bin/curl -s -X POST "http://localhost:$PORT/agentch?term=${TERM_PROGRAM:-}&pid=$PPID&tty=$TTY" \\
                -H 'Content-Type: application/json' --data-binary @- > /dev/null 2>&1 || true
        fi
        """

        let dir = (hookScriptPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? scriptContent.write(toFile: hookScriptPath, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hookScriptPath)
    }

    // MARK: - Read/Write settings

    static func readSettings(for agent: AgentHookConfig) throws -> [String: Any] {
        let path = agent.settingsPath
        guard FileManager.default.fileExists(atPath: path) else { return [:] }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return json
    }

    static func writeSettings(_ settings: [String: Any], for agent: AgentHookConfig) throws {
        let path = agent.settingsPath
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: path).deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
    }

    // MARK: - Install/Uninstall

    static func mergeHooks(into settings: [String: Any], port: UInt16, agent: AgentHookConfig) throws -> [String: Any] {
        var result = settings
        var hooks = (result["hooks"] as? [String: Any]) ?? [:]

        for event in agent.hookEvents {
            var matcherGroups = (hooks[event] as? [[String: Any]]) ?? []

            let alreadyExists = matcherGroups.contains { group in
                guard let groupHooks = group["hooks"] as? [[String: Any]] else { return false }
                return groupHooks.contains { ($0["command"] as? String)?.contains(hookIdentifier) == true }
            }

            if !alreadyExists {
                let timeout: Int = (event == "PermissionRequest" || event == "Elicitation") ? 300 : 5
                let ourHook: [String: Any] = [
                    "type": "command",
                    "command": hookCommand(port: port),
                    "timeout": timeout,
                ]
                var matcherGroup: [String: Any] = [
                    "hooks": [ourHook]
                ]
                // Claude requires "matcher" key; Codex works without it
                if agent == .claude {
                    matcherGroup["matcher"] = ""
                }
                matcherGroups.append(matcherGroup)
            }

            hooks[event] = matcherGroups
        }

        result["hooks"] = hooks
        return result
    }

    static func removeHooks(from settings: [String: Any], agent: AgentHookConfig) -> [String: Any] {
        var result = settings
        guard var hooks = result["hooks"] as? [String: Any] else { return result }

        for event in agent.hookEvents {
            guard var matcherGroups = hooks[event] as? [[String: Any]] else { continue }

            matcherGroups = matcherGroups.compactMap { group in
                var group = group
                guard var groupHooks = group["hooks"] as? [[String: Any]] else { return group }
                groupHooks.removeAll { ($0["command"] as? String)?.contains(hookIdentifier) == true }
                if groupHooks.isEmpty { return nil }
                group["hooks"] = groupHooks
                return group
            }

            hooks[event] = matcherGroups
        }

        result["hooks"] = hooks
        return result
    }

    static func isInstalled(in settings: [String: Any], port: UInt16, agent: AgentHookConfig) -> Bool {
        guard let hooks = settings["hooks"] as? [String: Any] else { return false }
        return agent.requiredEvents.allSatisfy { event in
            guard let matcherGroups = hooks[event] as? [[String: Any]] else { return false }
            return matcherGroups.contains { group in
                guard let groupHooks = group["hooks"] as? [[String: Any]] else { return false }
                return groupHooks.contains { ($0["command"] as? String)?.contains(hookIdentifier) == true }
            }
        }
    }

    // MARK: - High-level operations

    static func install(port: UInt16, agent: AgentHookConfig) throws {
        let settings = try readSettings(for: agent)
        let updated = try mergeHooks(into: settings, port: port, agent: agent)
        try writeSettings(updated, for: agent)
    }

    static func uninstall(agent: AgentHookConfig) throws {
        let settings = try readSettings(for: agent)
        let updated = removeHooks(from: settings, agent: agent)
        try writeSettings(updated, for: agent)
    }

    static func checkInstalled(port: UInt16, agent: AgentHookConfig) -> Bool {
        guard let settings = try? readSettings(for: agent) else { return false }
        return isInstalled(in: settings, port: port, agent: agent)
    }

    /// Install hooks for all supported agents.
    static func installAll(port: UInt16) {
        installScript()
        for agent in AgentHookConfig.all {
            do {
                try install(port: port, agent: agent)
            } catch {
                NSLog("[agentch] Failed to install hooks for %@: %@", agent.label, error.localizedDescription)
            }
        }
    }

    /// Uninstall hooks for all supported agents.
    static func uninstallAll() {
        for agent in AgentHookConfig.all {
            try? uninstall(agent: agent)
        }
    }

    /// Check if hooks are installed for all supported agents.
    static func checkAllInstalled(port: UInt16) -> [AgentHookConfig: Bool] {
        var result: [AgentHookConfig: Bool] = [:]
        for agent in AgentHookConfig.all {
            result[agent] = checkInstalled(port: port, agent: agent)
        }
        return result
    }
}
