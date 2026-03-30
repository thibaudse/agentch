import Testing
import Foundation
@testable import AgentCh

@Test func installHooksIntoEmptySettings() throws {
    let empty: [String: Any] = [:]
    let result = try HookManager.mergeHooks(into: empty, port: 27182)
    let hooks = result["hooks"] as! [String: [[String: Any]]]

    // Each event gets one matcher group
    #expect(hooks["SessionStart"]?.count == 1)
    #expect(hooks["SessionEnd"]?.count == 1)
    #expect(hooks["PreToolUse"]?.count == 1)
    #expect(hooks["Stop"]?.count == 1)

    // Verify the matcher group structure
    let group = hooks["SessionStart"]!.first!
    #expect(group["matcher"] as? String == "")
    let groupHooks = group["hooks"] as! [[String: Any]]
    #expect(groupHooks.count == 1)
    #expect(groupHooks.first?["url"] as? String == "http://localhost:27182/events")
    #expect(groupHooks.first?["type"] as? String == "http")
}

@Test func installHooksPreservesExistingHooks() throws {
    let existing: [String: Any] = [
        "hooks": [
            "SessionStart": [
                ["matcher": "Bash", "hooks": [["type": "command", "command": "echo hello"]]]
            ]
        ]
    ]
    let result = try HookManager.mergeHooks(into: existing, port: 27182)
    let hooks = result["hooks"] as! [String: [[String: Any]]]

    // Existing matcher group preserved + ours added
    #expect(hooks["SessionStart"]?.count == 2)
    #expect(hooks["SessionEnd"]?.count == 1)
}

@Test func installHooksSkipsDuplicates() throws {
    let existing: [String: Any] = [
        "hooks": [
            "SessionStart": [
                ["matcher": "", "hooks": [["type": "http", "url": "http://localhost:27182/events"]]]
            ]
        ]
    ]
    let result = try HookManager.mergeHooks(into: existing, port: 27182)
    let hooks = result["hooks"] as! [String: [[String: Any]]]

    // Should not duplicate
    #expect(hooks["SessionStart"]?.count == 1)
}

@Test func uninstallHooksRemovesOnlyOurs() throws {
    let settings: [String: Any] = [
        "hooks": [
            "SessionStart": [
                ["matcher": "Bash", "hooks": [["type": "command", "command": "echo hello"]]],
                ["matcher": "", "hooks": [["type": "http", "url": "http://localhost:27182/events"]]]
            ],
            "SessionEnd": [
                ["matcher": "", "hooks": [["type": "http", "url": "http://localhost:27182/events"]]]
            ]
        ]
    ]
    let result = HookManager.removeHooks(from: settings, port: 27182)
    let hooks = result["hooks"] as! [String: [[String: Any]]]

    // User's Bash hook preserved, our group removed
    #expect(hooks["SessionStart"]?.count == 1)
    #expect(hooks["SessionStart"]?.first?["matcher"] as? String == "Bash")
    // SessionEnd had only our hook, group removed
    #expect(hooks["SessionEnd"]?.isEmpty ?? true)
}

@Test func hookInstallationStatus() throws {
    // Fully installed — all 4 hook events with correct matcher group format
    let fullyInstalled: [String: Any] = [
        "hooks": [
            "SessionStart": [["matcher": "", "hooks": [["type": "http", "url": "http://localhost:27182/events"]]]],
            "SessionEnd": [["matcher": "", "hooks": [["type": "http", "url": "http://localhost:27182/events"]]]],
            "PreToolUse": [["matcher": "", "hooks": [["type": "http", "url": "http://localhost:27182/events"]]]],
            "Stop": [["matcher": "", "hooks": [["type": "http", "url": "http://localhost:27182/events"]]]],
        ]
    ]
    #expect(HookManager.isInstalled(in: fullyInstalled, port: 27182) == true)

    // Partially installed — only 1 of 4 events
    let partiallyInstalled: [String: Any] = [
        "hooks": [
            "SessionStart": [["matcher": "", "hooks": [["type": "http", "url": "http://localhost:27182/events"]]]]
        ]
    ]
    #expect(HookManager.isInstalled(in: partiallyInstalled, port: 27182) == false)

    // Not installed
    let notInstalled: [String: Any] = [:]
    #expect(HookManager.isInstalled(in: notInstalled, port: 27182) == false)
}
