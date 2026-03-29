import Testing
import Foundation
@testable import AgentCh

@Test func sessionCreation() {
    let session = Session(
        id: "abc123",
        agentType: .claude,
        label: "agentch/main",
        status: .idle,
        startedAt: Date()
    )
    #expect(session.id == "abc123")
    #expect(session.agentType == .claude)
    #expect(session.label == "agentch/main")
    #expect(session.status == .idle)
}

@Test func labelFromWorktree() {
    let label = Session.deriveLabel(
        cwd: "/Users/thibaud/Projects/agentch-feat-auth",
        gitBranch: "feat/auth",
        isWorktree: true
    )
    #expect(label == "feat/auth")
}

@Test func labelFromBranch() {
    let label = Session.deriveLabel(
        cwd: "/Users/thibaud/Projects/agentch",
        gitBranch: "develop",
        isWorktree: false
    )
    #expect(label == "agentch/develop")
}

@Test func labelFromMainBranch() {
    let label = Session.deriveLabel(
        cwd: "/Users/thibaud/Projects/agentch",
        gitBranch: "main",
        isWorktree: false
    )
    #expect(label == "agentch")
}

@Test func labelFallbackNoGit() {
    let label = Session.deriveLabel(
        cwd: "/Users/thibaud/Projects/agentch",
        gitBranch: nil,
        isWorktree: false
    )
    #expect(label == "agentch")
}
