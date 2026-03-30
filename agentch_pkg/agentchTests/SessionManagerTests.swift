import Testing
import Foundation
@testable import agentch

private func event(_ type: SessionEventType, sessionId: String = "s1", cwd: String = "/Users/thibaud/Projects/myapp") -> SessionEvent {
    SessionEvent(event: type, sessionId: sessionId, cwd: cwd, agentType: "claude")
}

@Test @MainActor func addSession() {
    let manager = SessionManager()
    manager.handleEvent(event(.sessionStart))
    #expect(manager.sessions.count == 1)
    #expect(manager.sessions.first?.id == "s1")
    #expect(manager.sessions.first?.status == .idle)
    #expect(manager.sessions.first?.agentType == .claude)
}

@Test @MainActor func removeSession() {
    let manager = SessionManager()
    manager.handleEvent(event(.sessionStart))
    manager.handleEvent(event(.sessionEnd))
    #expect(manager.sessions.isEmpty)
}

@Test @MainActor func thinkingTransition() {
    let manager = SessionManager()
    manager.handleEvent(event(.sessionStart))
    manager.handleEvent(event(.preToolUse))
    #expect(manager.sessions.first?.status == .thinking)
}

@Test @MainActor func stopTransition() {
    let manager = SessionManager()
    manager.handleEvent(event(.sessionStart))
    manager.handleEvent(event(.preToolUse))
    manager.handleEvent(event(.stop))
    #expect(manager.sessions.first?.status == .waiting)
}

@Test @MainActor func userPromptSetsThinking() {
    let manager = SessionManager()
    manager.handleEvent(event(.sessionStart))
    manager.handleEvent(event(.stop))
    #expect(manager.sessions.first?.status == .waiting)
    manager.handleEvent(event(.userPromptSubmit))
    #expect(manager.sessions.first?.status == .thinking)
}

@Test @MainActor func duplicateSessionStartIgnored() {
    let manager = SessionManager()
    let e = event(.sessionStart)
    manager.handleEvent(e)
    manager.handleEvent(e)
    #expect(manager.sessions.count == 1)
}

@Test @MainActor func unknownSessionEventIgnored() {
    let manager = SessionManager()
    manager.handleEvent(event(.preToolUse, sessionId: "unknown"))
    #expect(manager.sessions.isEmpty)
}
