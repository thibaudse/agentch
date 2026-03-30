import Foundation

struct HookManager {
    static let hookEvents = ["SessionStart", "SessionEnd", "PreToolUse", "Stop", "UserPromptSubmit", "PermissionRequest"]

    static var settingsPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.claude/settings.json"
    }

    private static func agentChURL(port: UInt16) -> String {
        "http://localhost:\(port)/events"
    }

    private static func hookCommand(port: UInt16) -> String {
        "TTY=$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' '); curl -s -X POST \"http://localhost:\(port)/agentch?term=${TERM_PROGRAM:-}&pid=$PPID&tty=$TTY\" -H 'Content-Type: application/json' --data-binary @- > /dev/null 2>&1 || true"
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
