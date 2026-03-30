import Foundation
import SwiftUI

enum SessionEventType: String, Codable, Sendable {
    case sessionStart = "SessionStart"
    case sessionEnd = "SessionEnd"
    case preToolUse = "PreToolUse"
    case userPromptSubmit = "UserPromptSubmit"
    case stop = "Stop"
}

struct SessionEvent: Sendable {
    let event: SessionEventType
    let sessionId: String
    let cwd: String
    let agentType: String
    var termProgram: String?
    var termPid: Int?
    var tty: String?

    static func from(json: [String: Any], queryParams: [String: String] = [:]) -> SessionEvent? {
        guard let hookEventName = json["hook_event_name"] as? String,
              let event = SessionEventType(rawValue: hookEventName),
              let sessionId = json["session_id"] as? String else {
            return nil
        }
        let cwd = json["cwd"] as? String ?? ""
        let agentType = json["agent_type"] as? String ?? "claude"
        let termProgram = queryParams["term"]?.isEmpty == true ? nil : queryParams["term"]
        let termPid = queryParams["pid"].flatMap(Int.init)
        let tty = queryParams["tty"]?.isEmpty == true ? nil : queryParams["tty"]
        return SessionEvent(
            event: event, sessionId: sessionId, cwd: cwd, agentType: agentType,
            termProgram: termProgram, termPid: termPid, tty: tty
        )
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
            // Capture the active tab title from the terminal (best effort)
            let tabTitle = event.termPid.flatMap { TerminalFocuser.captureActiveTabTitle(claudePid: $0) }

            let session = Session(
                id: event.sessionId,
                agentType: agentType,
                label: folderName,
                status: .idle,
                startedAt: Date(),
                cwd: event.cwd,
                termProgram: event.termProgram,
                termPid: event.termPid,
                tty: event.tty,
                tabTitle: tabTitle
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

        case .preToolUse, .userPromptSubmit:
            guard let index = sessions.firstIndex(where: { $0.id == event.sessionId }) else { return }
            sessions[index].status = .thinking
            updateTermInfo(at: index, from: event)

        case .stop:
            guard let index = sessions.firstIndex(where: { $0.id == event.sessionId }) else { return }
            sessions[index].status = .waiting
            updateTermInfo(at: index, from: event)
        }
    }

    private func updateTermInfo(at index: Int, from event: SessionEvent) {
        if let term = event.termProgram, sessions[index].termProgram == nil {
            sessions[index].termProgram = term
        }
        if let pid = event.termPid {
            sessions[index].termPid = pid
            // Update tab title — it changes as Claude works on different tasks
            if let title = TerminalFocuser.captureActiveTabTitle(claudePid: pid) {
                sessions[index].tabTitle = title
            }
        }
        if let tty = event.tty, sessions[index].tty == nil {
            sessions[index].tty = tty
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
