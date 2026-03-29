import Foundation
import SwiftUI

enum SessionEventType: String, Codable, Sendable {
    case sessionStart = "session_start"
    case sessionEnd = "session_end"
    case toolUse = "tool_use"
    case stop = "stop"
}

struct SessionEvent: Codable, Sendable {
    let event: SessionEventType
    let sessionId: String
    let cwd: String
    let agentType: String
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case event
        case sessionId = "session_id"
        case cwd
        case agentType = "agent_type"
        case timestamp
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
            let label = Session.deriveLabel(
                cwd: event.cwd,
                gitBranch: gitBranch(at: event.cwd),
                isWorktree: isGitWorktree(at: event.cwd)
            )
            let session = Session(
                id: event.sessionId,
                agentType: agentType,
                label: label,
                status: .idle,
                startedAt: event.timestamp
            )
            sessions.append(session)

        case .sessionEnd:
            sessions.removeAll { $0.id == event.sessionId }

        case .toolUse:
            guard let index = sessions.firstIndex(where: { $0.id == event.sessionId }) else { return }
            sessions[index].status = .thinking

        case .stop:
            guard let index = sessions.firstIndex(where: { $0.id == event.sessionId }) else { return }
            sessions[index].status = .idle
        }
    }

    private func gitBranch(at path: String) -> String? {
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

    private func isGitWorktree(at path: String) -> Bool {
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
