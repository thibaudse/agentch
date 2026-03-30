import Foundation
import SwiftUI

enum SessionEventType: String, Codable, Sendable {
    case sessionStart = "SessionStart"
    case sessionEnd = "SessionEnd"
    case preToolUse = "PreToolUse"
    case stop = "Stop"
}

struct SessionEvent: Sendable {
    let event: SessionEventType
    let sessionId: String
    let cwd: String
    let agentType: String

    /// Parse from Claude's native hook payload.
    /// Claude sends: { "hook_event_name": "SessionStart", "session_id": "...", "cwd": "...", ... }
    static func from(json: [String: Any]) -> SessionEvent? {
        guard let hookEventName = json["hook_event_name"] as? String,
              let event = SessionEventType(rawValue: hookEventName),
              let sessionId = json["session_id"] as? String else {
            return nil
        }
        let cwd = json["cwd"] as? String ?? ""
        // agent_type is not sent by Claude — default to "claude"
        let agentType = json["agent_type"] as? String ?? "claude"
        return SessionEvent(event: event, sessionId: sessionId, cwd: cwd, agentType: agentType)
    }
}

@MainActor
final class SessionManager: ObservableObject {
    @Published var sessions: [Session] = []

    func handleEvent(_ event: SessionEvent) {
        switch event.event {
        case .sessionStart:
            guard !sessions.contains(where: { $0.id == event.sessionId }) else { return }
            let agentType = AgentType(rawValue: event.agentType) ?? .unknown
            // Use folder name as temporary label, resolve git info in background
            let folderName = URL(fileURLWithPath: event.cwd).lastPathComponent
            let session = Session(
                id: event.sessionId,
                agentType: agentType,
                label: folderName,
                status: .idle,
                startedAt: Date()
            )
            withAnimation(.spring(duration: 0.3)) {
                sessions.append(session)
            }
            // Resolve git branch/worktree off main thread
            let cwd = event.cwd
            let sessionId = event.sessionId
            Task.detached { [weak self] in
                let branch = Self.gitBranch(at: cwd)
                let isWorktree = Self.isGitWorktree(at: cwd)
                let label = Session.deriveLabel(cwd: cwd, gitBranch: branch, isWorktree: isWorktree)
                await self?.updateLabel(sessionId: sessionId, label: label)
            }

        case .sessionEnd:
            withAnimation(.spring(duration: 0.3)) {
                sessions.removeAll { $0.id == event.sessionId }
            }

        case .preToolUse:
            guard let index = sessions.firstIndex(where: { $0.id == event.sessionId }) else { return }
            sessions[index].status = .thinking

        case .stop:
            guard let index = sessions.firstIndex(where: { $0.id == event.sessionId }) else { return }
            sessions[index].status = .idle
        }
    }

    private func updateLabel(sessionId: String, label: String) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].label = label
    }

    nonisolated private static func gitBranch(at path: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-parse", "--abbrev-ref", "HEAD"]
        process.currentDirectoryURL = URL(fileURLWithPath: path)
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let branch = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return branch?.isEmpty == true ? nil : branch
        } catch {
            return nil
        }
    }

    nonisolated private static func isGitWorktree(at path: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-parse", "--git-common-dir"]
        process.currentDirectoryURL = URL(fileURLWithPath: path)
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let commonDir = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return commonDir != ".git" && !commonDir.isEmpty
        } catch {
            return false
        }
    }
}
