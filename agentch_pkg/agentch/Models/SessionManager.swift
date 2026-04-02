import Foundation
import SwiftUI

enum SessionEventType: String, Codable, Sendable {
    case sessionStart = "SessionStart"
    case sessionEnd = "SessionEnd"
    case preToolUse = "PreToolUse"
    case postToolUse = "PostToolUse"
    case userPromptSubmit = "UserPromptSubmit"
    case permissionRequest = "PermissionRequest"
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
        // Detect agent type from process name if not provided
        let agentType: String
        if let provided = json["agent_type"] as? String, !provided.isEmpty {
            agentType = provided
        } else if let pid = queryParams["pid"].flatMap(Int.init) {
            agentType = detectAgentType(pid: pid)
        } else {
            agentType = "claude"
        }
        let termProgram = queryParams["term"]?.isEmpty == true ? nil : queryParams["term"]
        let termPid = queryParams["pid"].flatMap(Int.init)
        let tty = queryParams["tty"]?.isEmpty == true ? nil : queryParams["tty"]
        return SessionEvent(
            event: event, sessionId: sessionId, cwd: cwd, agentType: agentType,
            termProgram: termProgram, termPid: termPid, tty: tty
        )
    }

    /// Detect agent type from the process name at the given PID.
    private static func detectAgentType(pid: Int) -> String {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, Int32(pid)]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { return "claude" }
        let name = withUnsafePointer(to: &info.kp_proc.p_comm) {
            $0.withMemoryRebound(to: CChar.self, capacity: 16) {
                String(cString: $0)
            }
        }
        if name.lowercased().contains("codex") { return "codex" }
        return "claude"
    }
}

@MainActor
final class SessionManager: ObservableObject {
    @Published var sessions: [Session] = []
    private var cleanupTask: Task<Void, Never>?

    /// Start periodic cleanup of dead sessions (process no longer running).
    func startCleanup() {
        cleanupTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard let self else { return }
                self.removeDeadSessions()
            }
        }
    }

    private func removeDeadSessions() {
        let dead = sessions.filter { session in
            guard let pid = session.termPid else { return false }
            // Check if the process is still alive
            return kill(pid_t(pid), 0) != 0
        }
        if !dead.isEmpty {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
                sessions.removeAll { session in dead.contains(where: { $0.id == session.id }) }
            }
        }
    }

    func handleEvent(_ event: SessionEvent) {
        // Auto-create session if we receive an event for an unknown session
        // (e.g., agentch started while Claude sessions were already running)
        if event.event != .sessionEnd && event.event != .sessionStart {
            if !sessions.contains(where: { $0.id == event.sessionId }) {
                createSession(from: event)
            }
        }

        switch event.event {
        case .sessionStart:
            if !sessions.contains(where: { $0.id == event.sessionId }) {
                createSession(from: event)
            }

        case .sessionEnd:
            withAnimation(.spring(duration: 0.3)) {
                sessions.removeAll { $0.id == event.sessionId }
            }

        case .userPromptSubmit:
            guard let index = sessions.firstIndex(where: { $0.id == event.sessionId }) else { return }
            sessions[index].status = .thinking
            updateTermInfo(at: index, from: event)

        case .preToolUse, .postToolUse:
            guard let index = sessions.firstIndex(where: { $0.id == event.sessionId }) else { return }
            sessions[index].status = .thinking
            updateTermInfo(at: index, from: event)

        case .permissionRequest:
            guard let index = sessions.firstIndex(where: { $0.id == event.sessionId }) else { return }
            let wasNotWaiting = sessions[index].status != .waiting
            sessions[index].status = .waiting
            updateTermInfo(at: index, from: event)
            if wasNotWaiting { SoundPlayer.playAttentionSound() }

        case .stop:
            guard let index = sessions.firstIndex(where: { $0.id == event.sessionId }) else { return }
            let wasNotWaiting = sessions[index].status != .waiting
            sessions[index].status = .waiting
            updateTermInfo(at: index, from: event)
            if wasNotWaiting { SoundPlayer.playAttentionSound() }
        }
    }

    private func createSession(from event: SessionEvent) {
        let agentType = AgentType(rawValue: event.agentType) ?? .claude
        let folderName = URL(fileURLWithPath: event.cwd).lastPathComponent

        let session = Session(
            id: event.sessionId,
            agentType: agentType,
            label: folderName,
            status: .idle,
            startedAt: Date(),
            cwd: event.cwd,
            termProgram: event.termProgram,
            termPid: event.termPid,
            tty: event.tty
        )
        withAnimation(.spring(duration: 0.3)) {
            sessions.append(session)
        }
        let cwd = event.cwd
        let sessionId = event.sessionId
        Task.detached { [weak self] in
            let branch = Self.gitBranch(at: cwd)
            let isWorktree = Self.isGitWorktree(at: cwd)
            let label = Session.deriveLabel(cwd: cwd, gitBranch: branch, isWorktree: isWorktree)
            await self?.updateLabel(sessionId: sessionId, label: label)
        }
    }

    private func updateTermInfo(at index: Int, from event: SessionEvent) {
        if let term = event.termProgram, sessions[index].termProgram == nil {
            sessions[index].termProgram = term
        }
        if let pid = event.termPid {
            sessions[index].termPid = pid
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
