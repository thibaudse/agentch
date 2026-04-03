import Foundation

enum AgentType: String, Codable, Sendable, Equatable {
    case claude
    case codex
    case unknown
}

enum SessionStatus: String, Codable, Sendable, Equatable {
    case thinking
    case waiting
    case idle
    case error

    var sortOrder: Int {
        switch self {
        case .waiting: return 0
        case .thinking: return 1
        case .error: return 2
        case .idle: return 3
        }
    }
}

struct Session: Identifiable, Sendable {
    let id: String
    let agentType: AgentType
    var label: String
    var status: SessionStatus
    let startedAt: Date
    let cwd: String
    var termProgram: String?
    var termPid: Int?
    var tty: String?
    var tabTitle: String?
    var pendingPermission: PermissionRequest?
    var pendingQuestion: PendingQuestion?

    static let defaultBranches: Set<String> = ["main", "master"]

    static func deriveLabel(cwd: String, gitBranch: String?, isWorktree: Bool) -> String {
        let folderName = URL(fileURLWithPath: cwd).lastPathComponent

        guard let branch = gitBranch else {
            return folderName
        }

        if isWorktree {
            return branch
        }

        if defaultBranches.contains(branch) {
            return folderName
        }

        return "\(folderName)/\(branch)"
    }
}

struct PermissionRequest: Sendable {
    let toolName: String
    let toolInput: String
    let filePath: String?
}

struct QuestionOption: Sendable {
    let label: String
}

struct PendingQuestion: Sendable {
    let question: String
    let options: [QuestionOption]
}
