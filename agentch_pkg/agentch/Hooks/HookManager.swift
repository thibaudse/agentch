import Foundation

struct HookManager {
    static let hookEvents = ["SessionStart", "SessionEnd", "PreToolUse", "PostToolUse", "Stop", "UserPromptSubmit", "PermissionRequest"]

    static var settingsPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.claude/settings.json"
    }

    private static func agentChURL(port: UInt16) -> String {
        "http://localhost:\(port)/events"
    }

    /// Path to the hook helper script (installed alongside the binary)
    static var hookScriptPath: String {
        // Use a well-known location
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.agentch/hook.sh"
    }

    private static func hookCommand(port: UInt16) -> String {
        "AGENTCH_PORT=\(port) bash \(hookScriptPath)"
    }

    /// Install the hook helper script to ~/.agentch/hook.sh
    static func installScript() {
        let scriptContent = """
        #!/bin/bash
        PORT="${AGENTCH_PORT:-27182}"
        INPUT=$(cat)
        SID=$(echo "$INPUT" | grep -o '"session_id":"[^"]*"' | head -1 | cut -d'"' -f4)
        [ -z "$SID" ] && exit 0
        TTY=$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')

        # Walk up to find terminal app PID
        TPID=$PPID
        for i in $(seq 1 10); do
            PARENT=$(ps -o ppid= -p $TPID 2>/dev/null | tr -d ' ')
            [ -z "$PARENT" ] || [ "$PARENT" -le 1 ] && break
            TPID=$PARENT
            osascript -e "tell application \\"System Events\\" to return (count of windows of first process whose unix id is $TPID)" 2>/dev/null | grep -q '[1-9]' && break
        done

        # Save terminal window title for tab matching
        mkdir -p /tmp/agentch
        [ -n "$TPID" ] && [ "$TPID" -gt 1 ] && \\
            osascript -e "tell application \\"System Events\\" to return name of front window of first process whose unix id is $TPID" \\
            > "/tmp/agentch/$SID" 2>/dev/null

        echo "$INPUT" | curl -s -X POST "http://localhost:$PORT/agentch?term=${TERM_PROGRAM:-}&pid=$PPID&tty=$TTY" \\
            -H 'Content-Type: application/json' --data-binary @- > /dev/null 2>&1 || true
        """

        let dir = (hookScriptPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? scriptContent.write(toFile: hookScriptPath, atomically: true, encoding: .utf8)
        // Make executable
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hookScriptPath)
    }


    static let hookIdentifier = "agentch"

    // MARK: - Read/Write settings.json

    static func readSettings() throws -> [String: Any] {
        let url = URL(fileURLWithPath: settingsPath)
        guard FileManager.default.fileExists(atPath: settingsPath) else {
            return [:]
        }
        let data = try Data(contentsOf: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }

    static func writeSettings(_ settings: [String: Any]) throws {
        let url = URL(fileURLWithPath: settingsPath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Install/Uninstall

    static func mergeHooks(into settings: [String: Any], port: UInt16) throws -> [String: Any] {
        var result = settings
        var hooks = (settings["hooks"] as? [String: Any]) ?? [:]

        for event in hookEvents {
            var matcherGroups = (hooks[event] as? [[String: Any]]) ?? []

            let alreadyExists = matcherGroups.contains { group in
                guard let groupHooks = group["hooks"] as? [[String: Any]] else { return false }
                return groupHooks.contains { ($0["command"] as? String)?.contains(hookIdentifier) == true }
            }

            if !alreadyExists {
                let command = hookCommand(port: port)

                let ourHook: [String: Any] = [
                    "type": "command",
                    "command": command,
                    "timeout": 5,
                    "async": true,
                ]
                let matcherGroup: [String: Any] = [
                    "matcher": "",
                    "hooks": [ourHook]
                ]
                matcherGroups.append(matcherGroup)
            }

            hooks[event] = matcherGroups
        }

        result["hooks"] = hooks
        return result
    }

    static func removeHooks(from settings: [String: Any], port: UInt16) -> [String: Any] {
        var result = settings
        guard var hooks = settings["hooks"] as? [String: Any] else { return result }
        let url = agentChURL(port: port)

        for event in hookEvents {
            guard var matcherGroups = hooks[event] as? [[String: Any]] else { continue }

            matcherGroups = matcherGroups.compactMap { group in
                if group["hooks"] == nil && (group["url"] as? String) == url {
                    return nil
                }
                var group = group
                guard var groupHooks = group["hooks"] as? [[String: Any]] else { return group }
                groupHooks.removeAll {
                    ($0["url"] as? String) == url ||
                    ($0["command"] as? String)?.contains(hookIdentifier) == true
                }
                if groupHooks.isEmpty { return nil }
                group["hooks"] = groupHooks
                return group
            }

            hooks[event] = matcherGroups
        }

        result["hooks"] = hooks
        return result
    }

    static func isInstalled(in settings: [String: Any], port: UInt16) -> Bool {
        guard let hooks = settings["hooks"] as? [String: Any] else { return false }
        return hookEvents.allSatisfy { event in
            guard let matcherGroups = hooks[event] as? [[String: Any]] else { return false }
            return matcherGroups.contains { group in
                guard let groupHooks = group["hooks"] as? [[String: Any]] else { return false }
                return groupHooks.contains { ($0["command"] as? String)?.contains(hookIdentifier) == true }
            }
        }
    }

    // MARK: - High-level operations

    static func install(port: UInt16) throws {
        let settings = try readSettings()
        let updated = try mergeHooks(into: settings, port: port)
        try writeSettings(updated)
    }

    static func uninstall(port: UInt16) throws {
        let settings = try readSettings()
        let updated = removeHooks(from: settings, port: port)
        try writeSettings(updated)
    }

    static func checkInstalled(port: UInt16) -> Bool {
        guard let settings = try? readSettings() else { return false }
        return isInstalled(in: settings, port: port)
    }
}
