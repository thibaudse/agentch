import Testing
import Foundation
@testable import AgentCh

@Test func installHooksIntoEmptySettings() throws {
    let empty: [String: Any] = [:]
    let result = try HookManager.mergeHooks(into: empty, port: 27182)
    let hooks = result["hooks"] as! [String: [[String: Any]]]

    #expect(hooks["SessionStart"]?.count == 1)
    #expect(hooks["SessionEnd"]?.count == 1)
    #expect(hooks["PreToolUse"]?.count == 1)
    #expect(hooks["Stop"]?.count == 1)

    let url = hooks["SessionStart"]!.first!["url"] as! String
    #expect(url == "http://localhost:27182/events")
}

@Test func installHooksPreservesExistingHooks() throws {
    let existing: [String: Any] = [
        "hooks": [
            "SessionStart": [
                ["type": "command", "command": "echo hello"]
            ]
        ]
    ]
    let result = try HookManager.mergeHooks(into: existing, port: 27182)
    let hooks = result["hooks"] as! [String: [[String: Any]]]

    #expect(hooks["SessionStart"]?.count == 2)
    #expect(hooks["SessionEnd"]?.count == 1)
}

@Test func installHooksSkipsDuplicates() throws {
    let existing: [String: Any] = [
        "hooks": [
            "SessionStart": [
                ["type": "http", "url": "http://localhost:27182/events"]
            ]
        ]
    ]
    let result = try HookManager.mergeHooks(into: existing, port: 27182)
    let hooks = result["hooks"] as! [String: [[String: Any]]]

    #expect(hooks["SessionStart"]?.count == 1)
}

@Test func uninstallHooksRemovesOnlyOurs() throws {
    let settings: [String: Any] = [
        "hooks": [
            "SessionStart": [
                ["type": "command", "command": "echo hello"],
                ["type": "http", "url": "http://localhost:27182/events"]
            ],
            "SessionEnd": [
                ["type": "http", "url": "http://localhost:27182/events"]
            ]
        ]
    ]
    let result = HookManager.removeHooks(from: settings, port: 27182)
    let hooks = result["hooks"] as! [String: [[String: Any]]]

    #expect(hooks["SessionStart"]?.count == 1)
    #expect(hooks["SessionStart"]?.first?["type"] as? String == "command")
    #expect(hooks["SessionEnd"]?.isEmpty ?? true)
}

@Test func hookInstallationStatus() throws {
    let installed: [String: Any] = [
        "hooks": [
            "SessionStart": [
                ["type": "http", "url": "http://localhost:27182/events"]
            ]
        ]
    ]
    #expect(HookManager.isInstalled(in: installed, port: 27182) == true)

    let notInstalled: [String: Any] = [:]
    #expect(HookManager.isInstalled(in: notInstalled, port: 27182) == false)
}
