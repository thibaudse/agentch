import Testing
import Foundation
@testable import AgentCh

@Test func parseSessionStartEvent() throws {
    let json = """
    {
        "event": "session_start",
        "session_id": "abc123",
        "cwd": "/Users/thibaud/Projects/agentch",
        "agent_type": "claude",
        "timestamp": "2026-03-30T12:00:00Z"
    }
    """.data(using: .utf8)!

    let event = try EventServer.parseEvent(from: json)
    #expect(event.event == .sessionStart)
    #expect(event.sessionId == "abc123")
    #expect(event.cwd == "/Users/thibaud/Projects/agentch")
    #expect(event.agentType == "claude")
}

@Test func parseToolUseEvent() throws {
    let json = """
    {
        "event": "tool_use",
        "session_id": "abc123",
        "cwd": "/Users/thibaud/Projects/agentch",
        "agent_type": "claude",
        "timestamp": "2026-03-30T12:00:01Z"
    }
    """.data(using: .utf8)!

    let event = try EventServer.parseEvent(from: json)
    #expect(event.event == .toolUse)
}

@Test func parseStopEvent() throws {
    let json = """
    {
        "event": "stop",
        "session_id": "abc123",
        "cwd": "/Users/thibaud/Projects/agentch",
        "agent_type": "claude",
        "timestamp": "2026-03-30T12:00:02Z"
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
