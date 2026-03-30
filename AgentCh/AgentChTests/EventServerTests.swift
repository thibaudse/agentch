import Testing
import Foundation
@testable import AgentCh

@Test func parseSessionStartEvent() throws {
    let json = """
    {
        "hook_event_name": "SessionStart",
        "session_id": "abc123",
        "cwd": "/Users/thibaud/Projects/agentch"
    }
    """.data(using: .utf8)!

    let event = try EventServer.parseEvent(from: json)
    #expect(event.event == .sessionStart)
    #expect(event.sessionId == "abc123")
    #expect(event.cwd == "/Users/thibaud/Projects/agentch")
    #expect(event.agentType == "claude")
}

@Test func parsePreToolUseEvent() throws {
    let json = """
    {
        "hook_event_name": "PreToolUse",
        "session_id": "abc123",
        "cwd": "/Users/thibaud/Projects/agentch",
        "tool_name": "Bash"
    }
    """.data(using: .utf8)!

    let event = try EventServer.parseEvent(from: json)
    #expect(event.event == .preToolUse)
}

@Test func parseStopEvent() throws {
    let json = """
    {
        "hook_event_name": "Stop",
        "session_id": "abc123",
        "cwd": "/Users/thibaud/Projects/agentch"
    }
    """.data(using: .utf8)!

    let event = try EventServer.parseEvent(from: json)
    #expect(event.event == .stop)
}

@Test func parseInvalidEventThrows() {
    let json = "not json".data(using: .utf8)!
    #expect(throws: (any Error).self) {
        try EventServer.parseEvent(from: json)
    }
}

@Test func httpResponseFormat() {
    let response = EventServer.httpResponse(status: 200, body: "{\"ok\":true}")
    let responseStr = String(data: response, encoding: .utf8)!
    #expect(responseStr.contains("HTTP/1.1 200 OK"))
    #expect(responseStr.contains("Content-Type: application/json"))
    #expect(responseStr.contains("{\"ok\":true}"))
}
