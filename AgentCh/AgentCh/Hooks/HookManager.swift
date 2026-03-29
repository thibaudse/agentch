import Foundation

struct HookManager {
    static let hookEvents = ["SessionStart", "SessionEnd", "PreToolUse", "Stop"]

    static var settingsPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.claude/settings.json"
    }

    private static func agentChURL(port: UInt16) -> String {
        "http://localhost:\(port)/events"
    }

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

    // MARK: - Install/Uninstall (pure functions for testability)

    static func mergeHooks(into settings: [String: Any], port: UInt16) throws -> [String: Any] {
        var result = settings
        var hooks = (settings["hooks"] as? [String: Any]) ?? [:]
        let url = agentChURL(port: port)

        for event in hookEvents {
            var eventHooks = (hooks[event] as? [[String: Any]]) ?? []
            let alreadyExists = eventHooks.contains { ($0["url"] as? String) == url }
            if !alreadyExists {
                eventHooks.append(["type": "http", "url": url])
            }
            hooks[event] = eventHooks
        }

        result["hooks"] = hooks
        return result
    }

    static func removeHooks(from settings: [String: Any], port: UInt16) -> [String: Any] {
        var result = settings
        guard var hooks = settings["hooks"] as? [String: Any] else { return result }
        let url = agentChURL(port: port)

        for event in hookEvents {
            guard var eventHooks = hooks[event] as? [[String: Any]] else { continue }
            eventHooks.removeAll { ($0["url"] as? String) == url }
            hooks[event] = eventHooks
        }

        result["hooks"] = hooks
        return result
    }

    static func isInstalled(in settings: [String: Any], port: UInt16) -> Bool {
        guard let hooks = settings["hooks"] as? [String: Any] else { return false }
        let url = agentChURL(port: port)
        return hookEvents.allSatisfy { event in
            guard let eventHooks = hooks[event] as? [[String: Any]] else { return false }
            return eventHooks.contains { ($0["url"] as? String) == url }
        }
    }

    // MARK: - High-level operations (touch filesystem)

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
