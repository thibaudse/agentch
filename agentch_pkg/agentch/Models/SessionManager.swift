import Foundation
import SwiftUI

enum SessionEventType: String, Codable, Sendable {
    case sessionStart = "SessionStart"
    case sessionEnd = "SessionEnd"
    case preToolUse = "PreToolUse"
    case postToolUse = "PostToolUse"
    case userPromptSubmit = "UserPromptSubmit"
    case permissionRequest = "PermissionRequest"
    case elicitation = "Elicitation"
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
    var toolName: String?
    var toolInput: String?
    var toolFilePath: String?
    var question: String?
    var questionOptions: [QuestionOption]?
    var questionMultiSelect: Bool?
    var lastAssistantMessage: String?
    var permissionSuggestions: [PermissionSuggestion]?

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
        let toolName = json["tool_name"] as? String
        let toolInput: String?
        var toolFilePath: String?
        if let input = json["tool_input"] as? [String: Any] {
            toolFilePath = input["file_path"] as? String
            if let command = input["command"] as? String {
                toolInput = command
            } else if toolName == "Edit",
                      let oldStr = input["old_string"] as? String,
                      let newStr = input["new_string"] as? String {
                toolInput = Self.formatDiff(old: oldStr, new: newStr, filePath: toolFilePath)
            } else if toolName == "Write",
                      let content = input["content"] as? String {
                toolInput = String(content.prefix(500))
            } else if let filePath = toolFilePath {
                toolInput = filePath
            } else if let data = try? JSONSerialization.data(withJSONObject: input, options: []),
                      let str = String(data: data, encoding: .utf8) {
                toolInput = String(str.prefix(200))
            } else {
                toolInput = nil
            }
        } else {
            toolInput = nil
        }
        // Parse question for Elicitation events and AskUserQuestion tool
        let question: String?
        var questionOptions: [[String: Any]]?
        var questionMultiSelect: Bool?
        if hookEventName == "Elicitation" {
            question = json["question"] as? String
                ?? (json["message"] as? String)
                ?? (json["description"] as? String)
            questionOptions = json["options"] as? [[String: Any]]
            questionMultiSelect = json["multiSelect"] as? Bool
        } else if toolName == "AskUserQuestion",
                  let input = json["tool_input"] as? [String: Any],
                  let questions = input["questions"] as? [[String: Any]],
                  let first = questions.first {
            question = first["question"] as? String
            questionOptions = first["options"] as? [[String: Any]]
            questionMultiSelect = first["multiSelect"] as? Bool
        } else {
            question = nil
        }

        // Parse last_assistant_message from Stop events
        let lastAssistantMessage = hookEventName == "Stop"
            ? json["last_assistant_message"] as? String
            : nil

        // Parse permission_suggestions from PermissionRequest events
        let permissionSuggestions: [PermissionSuggestion]?
        if hookEventName == "PermissionRequest",
           let suggestions = json["permission_suggestions"] as? [[String: Any]] {
            permissionSuggestions = suggestions.compactMap { s in
                let type = s["type"] as? String ?? ""
                let behavior = s["behavior"] as? String
                let mode = s["mode"] as? String
                let dest = s["destination"] as? String ?? "session"
                // Build human-readable label
                let label: String
                let icon: String
                if type == "setMode", let mode {
                    let modeLabel: String = switch mode {
                    case "acceptEdits": "Accept Edits"
                    case "auto": "Auto"
                    case "bypassPermissions": "Bypass"
                    default: mode
                    }
                    label = "Switch to \(modeLabel) mode"
                    icon = "arrow.triangle.2.circlepath"
                } else if let rules = s["rules"] as? [[String: Any]], let first = rules.first {
                    let rule = first["ruleContent"] as? String ?? ""
                    let shortRule = rule.components(separatedBy: "/").last ?? rule
                    let scope = dest == "session" ? "this session" : "always"
                    label = "Allow \(shortRule) for \(scope)"
                    icon = "checkmark.shield"
                } else {
                    label = type
                    icon = "questionmark.circle"
                }
                return PermissionSuggestion(type: type, behavior: behavior, mode: mode, label: label, icon: icon)
            }
        } else {
            permissionSuggestions = nil
        }

        return SessionEvent(
            event: event, sessionId: sessionId, cwd: cwd, agentType: agentType,
            termProgram: termProgram, termPid: termPid, tty: tty,
            toolName: toolName, toolInput: toolInput, toolFilePath: toolFilePath,
            question: question,
            questionOptions: questionOptions?.compactMap { opt in
                guard let label = opt["label"] as? String else { return nil }
                return QuestionOption(label: label)
            },
            questionMultiSelect: questionMultiSelect,
            lastAssistantMessage: lastAssistantMessage,
            permissionSuggestions: permissionSuggestions
        )
    }

    /// Format old/new strings as a unified diff with line numbers.
    /// Lines are formatted as "NNN - old" or "NNN + new" where NNN is the file line number.
    private static func formatDiff(old: String, new: String, filePath: String?) -> String {
        var startLine = 1
        if let filePath,
           let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
            let fileLines = content.components(separatedBy: "\n")
            let oldFirstLine = old.components(separatedBy: "\n").first ?? ""
            for (i, line) in fileLines.enumerated() {
                if line.contains(oldFirstLine) {
                    startLine = i + 1
                    break
                }
            }
        }

        let oldLines = old.components(separatedBy: "\n")
        let newLines = new.components(separatedBy: "\n")
        var result: [String] = []
        for (i, line) in oldLines.enumerated() {
            let lineNum = String(format: "%3d", startLine + i)
            result.append("\(lineNum) - \(line)")
        }
        for (i, line) in newLines.enumerated() {
            let lineNum = String(format: "%3d", startLine + i)
            result.append("\(lineNum) + \(line)")
        }
        return result.joined(separator: "\n")
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
    var onResolvePermission: ((String, Bool) -> Void)?
    var onResolveQuestion: ((String, String?) -> Void)?  // sessionId, answer (nil = skip)

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
        // Any event that indicates progress should clear pending permissions
        let clearEvents: Set<SessionEventType> = [.preToolUse, .postToolUse, .userPromptSubmit, .stop, .sessionEnd, .permissionRequest, .elicitation]
        if clearEvents.contains(event.event),
           let index = sessions.firstIndex(where: { $0.id == event.sessionId }),
           sessions[index].pendingPermission != nil {
            clearPermissionIfNeeded(at: index)
        }

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
            if let index = sessions.firstIndex(where: { $0.id == event.sessionId }),
               sessions[index].pendingPermission != nil {
                resolvePermission(sessionId: event.sessionId, allow: true)
            }
            withAnimation(.spring(duration: 0.3)) {
                sessions.removeAll { $0.id == event.sessionId }
            }

        case .userPromptSubmit:
            guard let index = sessions.firstIndex(where: { $0.id == event.sessionId }) else { return }
            clearPermissionIfNeeded(at: index)
            sessions[index].status = .thinking
            updateTermInfo(at: index, from: event)

        case .preToolUse:
            guard let index = sessions.firstIndex(where: { $0.id == event.sessionId }) else { return }
            clearPermissionIfNeeded(at: index)
            sessions[index].status = .thinking
            updateTermInfo(at: index, from: event)

        case .postToolUse:
            guard let index = sessions.firstIndex(where: { $0.id == event.sessionId }) else { return }
            clearPermissionIfNeeded(at: index)
            sessions[index].status = .thinking
            updateTermInfo(at: index, from: event)

        case .stop:
            guard let index = sessions.firstIndex(where: { $0.id == event.sessionId }) else { return }
            let wasNotWaiting = sessions[index].status != .waiting
            sessions[index].status = .waiting
            if let msg = event.lastAssistantMessage {
                sessions[index].lastAssistantMessage = msg
            }
            updateTermInfo(at: index, from: event)
            if wasNotWaiting { SoundPlayer.playAttentionSound() }

        case .permissionRequest:
            guard let index = sessions.firstIndex(where: { $0.id == event.sessionId }) else { return }
            let wasNotWaiting = sessions[index].status != .waiting
            sessions[index].status = .waiting
            updateTermInfo(at: index, from: event)
            if wasNotWaiting { SoundPlayer.playAttentionSound() }

        case .elicitation:
            guard let index = sessions.firstIndex(where: { $0.id == event.sessionId }) else { return }
            let wasNotWaiting = sessions[index].status != .waiting
            sessions[index].status = .waiting
            updateTermInfo(at: index, from: event)
            if wasNotWaiting { SoundPlayer.playAttentionSound() }
        }
    }

    private func clearPermissionIfNeeded(at index: Int) {
        if sessions[index].pendingPermission != nil {
            let sessionId = sessions[index].id
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                sessions[index].pendingPermission = nil
            }
            onResolvePermission?(sessionId, true)
        }
        if sessions[index].pendingQuestion != nil {
            let sessionId = sessions[index].id
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                sessions[index].pendingQuestion = nil
            }
            onResolveQuestion?(sessionId, nil)
        }
    }

    func resolvePermission(sessionId: String, allow: Bool) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].pendingPermission = nil
        sessions[index].status = allow ? .thinking : .waiting
        onResolvePermission?(sessionId, allow)
    }

    func setPermission(sessionId: String, toolName: String, toolInput: String?, filePath: String?, suggestions: [PermissionSuggestion] = []) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].pendingPermission = PermissionRequest(
            toolName: toolName,
            toolInput: toolInput ?? "",
            filePath: filePath,
            suggestions: suggestions
        )
        let wasNotWaiting = sessions[index].status != .waiting
        sessions[index].status = .waiting
        if wasNotWaiting { SoundPlayer.playAttentionSound() }
    }

    func setQuestion(sessionId: String, question: String, options: [QuestionOption] = [], isAskUserQuestion: Bool = false) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].pendingQuestion = PendingQuestion(question: question, options: options)
        sessions[index].isAskUserQuestion = isAskUserQuestion
        let wasNotWaiting = sessions[index].status != .waiting
        sessions[index].status = .waiting
        if wasNotWaiting { SoundPlayer.playAttentionSound() }
    }

    func resolveQuestion(sessionId: String, answer: String?) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].pendingQuestion = nil
        sessions[index].status = answer != nil ? .thinking : .waiting
        onResolveQuestion?(sessionId, answer)
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
        // Save tab title for jump-to-tab (async timing means it may be wrong tab,
        // but it's the best we have for matching)
        let path = "/tmp/agentch/\(event.sessionId)"
        if let title = try? String(contentsOfFile: path, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty {
            sessions[index].tabTitle = title
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
