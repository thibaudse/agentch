import Foundation
import Network

final class EventServer: @unchecked Sendable {
    let port: UInt16
    private let listener: NWListener
    private let onEvent: @Sendable (SessionEvent) -> Void
    private let onDecisionEvent: @Sendable (SessionEvent) -> Void
    private let pendingLock = NSLock()
    private var _pendingConnections: [String: NWConnection] = [:]

    private func storePending(sessionId: String, connection: NWConnection) {
        pendingLock.lock()
        _pendingConnections[sessionId] = connection
        pendingLock.unlock()
    }

    private func removePending(sessionId: String) -> NWConnection? {
        pendingLock.lock()
        let conn = _pendingConnections.removeValue(forKey: sessionId)
        pendingLock.unlock()
        return conn
    }

    func resolveDecision(sessionId: String, allow: Bool) {
        guard let connection = removePending(sessionId: sessionId) else { return }
        let body: String
        if allow {
            body = "{\"decision\":\"allow\"}"
        } else {
            body = "{\"decision\":\"deny\",\"reason\":\"Denied from AgentCh\"}"
        }
        let response = Self.httpResponse(status: 200, body: body)
        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    init(port: UInt16 = 27182, onEvent: @escaping @Sendable (SessionEvent) -> Void, onDecisionEvent: @escaping @Sendable (SessionEvent) -> Void) throws {
        self.port = port
        self.onEvent = onEvent
        self.onDecisionEvent = onDecisionEvent
        let params = NWParameters.tcp
        self.listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
    }

    func start() {
        listener.newConnectionHandler = { [onEvent, onDecisionEvent] connection in
            Self.handleConnection(
                connection,
                onEvent: onEvent,
                onDecisionEvent: onDecisionEvent,
                storePending: { [weak self] sessionId, conn in
                    self?.storePending(sessionId: sessionId, connection: conn)
                }
            )
        }
        listener.start(queue: .global(qos: .userInitiated))
    }

    func stop() {
        listener.cancel()
    }

    private static func handleConnection(
        _ connection: NWConnection,
        onEvent: @escaping @Sendable (SessionEvent) -> Void,
        onDecisionEvent: @escaping @Sendable (SessionEvent) -> Void,
        storePending: @escaping (String, NWConnection) -> Void
    ) {
        connection.start(queue: .global(qos: .userInitiated))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, error in
            guard let data = data, error == nil else {
                connection.cancel()
                return
            }

            let httpStr = String(data: data, encoding: .utf8) ?? ""
            let queryParams = Self.extractQueryParams(from: httpStr)
            let path = Self.extractPath(from: httpStr)

            guard let body = Self.extractHTTPBody(from: data) else {
                let response = Self.httpResponse(status: 400, body: "{\"error\":\"invalid request\"}")
                connection.send(content: response, completion: .contentProcessed { _ in
                    connection.cancel()
                })
                return
            }

            do {
                let event = try Self.parseEvent(from: body, queryParams: queryParams)

                if path == "/agentch/decision" {
                    onDecisionEvent(event)
                    storePending(event.sessionId, connection)
                } else {
                    onEvent(event)
                    let response = Self.httpResponse(status: 200, body: "{\"ok\":true}")
                    connection.send(content: response, completion: .contentProcessed { _ in
                        connection.cancel()
                    })
                }
            } catch {
                let response = Self.httpResponse(status: 400, body: "{\"error\":\"invalid event\"}")
                connection.send(content: response, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }
        }
    }

    static func parseEvent(from data: Data, queryParams: [String: String] = [:]) throws -> SessionEvent {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let event = SessionEvent.from(json: json, queryParams: queryParams) else {
            throw EventParseError.invalidPayload
        }
        return event
    }

    enum EventParseError: Error {
        case invalidPayload
    }

    static func extractQueryParams(from httpRequest: String) -> [String: String] {
        // Extract URL from first line: "POST /agentch?term=foo&pid=123 HTTP/1.1"
        guard let firstLine = httpRequest.split(separator: "\r\n").first ?? httpRequest.split(separator: "\n").first,
              let urlPart = firstLine.split(separator: " ").dropFirst().first,
              let queryStart = urlPart.firstIndex(of: "?") else {
            return [:]
        }
        let queryString = String(urlPart[urlPart.index(after: queryStart)...])
        var params: [String: String] = [:]
        for pair in queryString.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0]).removingPercentEncoding ?? String(parts[0])
                let value = String(parts[1]).removingPercentEncoding ?? String(parts[1])
                params[key] = value
            }
        }
        return params
    }

    static func extractPath(from httpRequest: String) -> String {
        guard let firstLine = httpRequest.split(separator: "\r\n").first ?? httpRequest.split(separator: "\n").first,
              let urlPart = firstLine.split(separator: " ").dropFirst().first else {
            return "/"
        }
        let urlStr = String(urlPart)
        if let qIndex = urlStr.firstIndex(of: "?") {
            return String(urlStr[..<qIndex])
        }
        return urlStr
    }

    static func extractHTTPBody(from data: Data) -> Data? {
        guard let str = String(data: data, encoding: .utf8) else { return nil }
        guard let range = str.range(of: "\r\n\r\n") else {
            return data
        }
        let bodyStr = String(str[range.upperBound...])
        return bodyStr.data(using: .utf8)
    }

    static func httpResponse(status: Int, body: String) -> Data {
        let statusText = status == 200 ? "OK" : "Bad Request"
        let response = "HTTP/1.1 \(status) \(statusText)\r\nContent-Type: application/json\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        return Data(response.utf8)
    }
}
