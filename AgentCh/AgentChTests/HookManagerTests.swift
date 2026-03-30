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

    let group = hooks["SessionStart"]!.first!
    #expect(group["matcher"] as? String == "")
    let groupHooks = group["hooks"] as! [[String: Any]]
    #expect(groupHooks.count == 1)
    #expect(groupHooks.first?["type"] as? String == "command")
    let command = groupHooks.first?["command"] as? String ?? ""
    #expect(command.contains("27182"))
    #expect(command.contains("agentch"))
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

    #expect(hooks["SessionStart"]?.count == 2)
    #expect(hooks["SessionEnd"]?.count == 1)
}

@Test func installHooksSkipsDuplicates() throws {
    let existing: [String: Any] = [
        "hooks": [
            "SessionStart": [
                ["matcher": "", "hooks": [["type": "command", "command": "curl -s -X POST http://localhost:27182/agentch -H 'Content-Type: application/json' -d \"$(cat)\" > /dev/null 2>&1 || true"]]]
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
                ["matcher": "Bash", "hooks": [["type": "command", "command": "echo hello"]]],
                ["matcher": "", "hooks": [["type": "command", "command": "curl -s -X POST http://localhost:27182/agentch -d test"]]]
            ],
            "SessionEnd": [
                ["matcher": "", "hooks": [["type": "command", "command": "curl -s -X POST http://localhost:27182/agentch -d test"]]]
            ]
        ]
    ]
    let result = HookManager.removeHooks(from: settings, port: 27182)
    let hooks = result["hooks"] as! [String: [[String: Any]]]

    #expect(hooks["SessionStart"]?.count == 1)
    #expect(hooks["SessionEnd"]?.isEmpty ?? true)
}

@Test func hookInstallationStatus() throws {
    let cmd = "curl -s -X POST http://localhost:27182/agentch -H 'Content-Type: application/json' -d \"$(cat)\" > /dev/null 2>&1 || true"
    let fullyInstalled: [String: Any] = [
        "hooks": [
            "SessionStart": [["matcher": "", "hooks": [["type": "command", "command": cmd]]]],
            "SessionEnd": [["matcher": "", "hooks": [["type": "command", "command": cmd]]]],
            "PreToolUse": [["matcher": "", "hooks": [["type": "command", "command": cmd]]]],
            "Stop": [["matcher": "", "hooks": [["type": "command", "command": cmd]]]],
        ]
    ]
    #expect(HookManager.isInstalled(in: fullyInstalled, port: 27182) == true)

    let notInstalled: [String: Any] = [:]
    #expect(HookManager.isInstalled(in: notInstalled, port: 27182) == false)
}
