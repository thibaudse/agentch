import Foundation

enum AgentType: String, Codable, Sendable, Equatable {
    case claude
    case codex
    case unknown
}

enum SessionStatus: String, Codable, Sendable, Equatable {
    case thinking
    case idle
    case error
}

struct Session: Identifiable, Sendable {
    let id: String
    let agentType: AgentType
    var label: String
    var status: SessionStatus
    let startedAt: Date

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
