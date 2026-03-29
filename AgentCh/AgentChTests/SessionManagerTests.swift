import Testing
import Foundation
@testable import AgentCh

@Test @MainActor func addSession() {
    let manager = SessionManager()
    manager.handleEvent(SessionEvent(
        event: .sessionStart,
        sessionId: "s1",
        cwd: "/Users/thibaud/Projects/myapp",
        agentType: "claude",
        timestamp: Date()
    ))
    #expect(manager.sessions.count == 1)
    #expect(manager.sessions.first?.id == "s1")
    #expect(manager.sessions.first?.status == .idle)
    #expect(manager.sessions.first?.agentType == .claude)
}

@Test @MainActor func removeSession() {
    let manager = SessionManager()
    manager.handleEvent(SessionEvent(
        event: .sessionStart,
        sessionId: "s1",
        cwd: "/Users/thibaud/Projects/myapp",
        agentType: "claude",
        timestamp: Date()
    ))
    manager.handleEvent(SessionEvent(
        event: .sessionEnd,
        sessionId: "s1",
        cwd: "/Users/thibaud/Projects/myapp",
        agentType: "claude",
        timestamp: Date()
    ))
    #expect(manager.sessions.isEmpty)
}

@Test @MainActor func thinkingTransition() {
    let manager = SessionManager()
    manager.handleEvent(SessionEvent(
        event: .sessionStart,
        sessionId: "s1",
        cwd: "/Users/thibaud/Projects/myapp",
        agentType: "claude",
        timestamp: Date()
    ))
    manager.handleEvent(SessionEvent(
        event: .toolUse,
        sessionId: "s1",
        cwd: "/Users/thibaud/Projects/myapp",
        agentType: "claude",
        timestamp: Date()
    ))
    #expect(manager.sessions.first?.status == .thinking)
}

@Test @MainActor func stopTransition() {
    let manager = SessionManager()
    manager.handleEvent(SessionEvent(
        event: .sessionStart,
        sessionId: "s1",
        cwd: "/Users/thibaud/Projects/myapp",
        agentType: "claude",
        timestamp: Date()
    ))
    manager.handleEvent(SessionEvent(
        event: .toolUse,
        sessionId: "s1",
        cwd: "/Users/thibaud/Projects/myapp",
        agentType: "claude",
        timestamp: Date()
    ))
    manager.handleEvent(SessionEvent(
        event: .stop,
        sessionId: "s1",
        cwd: "/Users/thibaud/Projects/myapp",
        agentType: "claude",
        timestamp: Date()
    ))
    #expect(manager.sessions.first?.status == .idle)
}

@Test @MainActor func duplicateSessionStartIgnored() {
    let manager = SessionManager()
    let event = SessionEvent(
        event: .sessionStart,
        sessionId: "s1",
        cwd: "/Users/thibaud/Projects/myapp",
        agentType: "claude",
        timestamp: Date()
    )
    manager.handleEvent(event)
    manager.handleEvent(event)
    #expect(manager.sessions.count == 1)
}

@Test @MainActor func unknownSessionEventIgnored() {
    let manager = SessionManager()
    manager.handleEvent(SessionEvent(
        event: .toolUse,
        sessionId: "unknown",
        cwd: "/Users/thibaud/Projects/myapp",
        agentType: "claude",
        timestamp: Date()
    ))
    #expect(manager.sessions.isEmpty)
}
