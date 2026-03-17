import Foundation

/// Represents an "always allow" suggestion from Claude Code's PermissionRequest.
/// Preserves the full raw JSON so we can echo it back verbatim.
struct PermissionSuggestion: Identifiable, @unchecked Sendable {
    /// The complete original dictionary — echoed back to the hook script as-is
    let raw: [String: Any]

    var type: String { raw["type"] as? String ?? "" }

    var id: String { "\(type):\(label)" }

    /// Human-readable label for the button
    var label: String {
        switch type {
        case "toolAlwaysAllow":
            let tool = raw["tool"] as? String ?? "this tool"
            return "Always allow \(tool)"
        case "addRules":
            if let rules = raw["rules"] as? [[String: String]], let first = rules.first {
                let toolName = first["toolName"] ?? ""
                let rule = first["ruleContent"] ?? ""
                if !rule.isEmpty {
                    return "Allow \(toolName): \(rule)"
                }
                return "Always allow \(toolName)"
            }
            return "Always allow"
        case "addDirectories":
            if let dirs = raw["directories"] as? [String], let first = dirs.first {
                let scope = raw["destination"] as? String ?? "session"
                return "Allow access to \(first) (\(scope))"
            }
            return "Allow directory access"
        case "setMode":
            let mode = raw["mode"] as? String ?? "unknown"
            return "Switch to \(mode) mode"
        default:
            return "Always allow"
        }
    }

    /// JSON string to pass back to the hook script — preserves all original fields
    var rawJSON: String {
        if let data = try? JSONSerialization.data(withJSONObject: raw, options: [.sortedKeys]),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }
}

extension PermissionSuggestion: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Decode via JSONSerialization to preserve all fields
        // We get here from JSONDecoder, so we need a workaround:
        // decode as a known-shape struct, then reconstruct the dict
        let helper = try container.decode(SuggestionHelper.self)
        self.raw = helper.asDict()
    }
}

/// Helper to decode the suggestion and then reconstruct a full dictionary
private struct SuggestionHelper: Decodable {
    let type: String
    let tool: String?
    let rules: [[String: String]]?
    let directories: [String]?
    let destination: String?
    let mode: String?
    let behavior: String?
    let ruleContent: String?
    let toolName: String?

    func asDict() -> [String: Any] {
        var d: [String: Any] = ["type": type]
        if let tool { d["tool"] = tool }
        if let rules { d["rules"] = rules }
        if let directories { d["directories"] = directories }
        if let destination { d["destination"] = destination }
        if let mode { d["mode"] = mode }
        if let behavior { d["behavior"] = behavior }
        if let ruleContent { d["ruleContent"] = ruleContent }
        if let toolName { d["toolName"] = toolName }
        return d
    }
}

/// A question from an AskUserQuestion elicitation.
struct ElicitationOption: Decodable, Identifiable, Sendable {
    let label: String
    let description: String?

    var id: String { label }
}

struct Elicitation: Decodable, Sendable {
    let question: String
    let options: [ElicitationOption]
}

enum IslandCommand: Sendable {
    case show(message: String, agent: String, duration: TimeInterval, pid: pid_t, interactive: Bool, terminalBundle: String, tabMarker: String, ttyPath: String, conversation: String, responsePipe: String, sessionID: String, sessionLabel: String)
    case permission(tool: String, command: String, agent: String, pid: pid_t, responsePipe: String, suggestions: [PermissionSuggestion], sessionID: String, sessionLabel: String)
    case elicitation(question: Elicitation, agent: String, pid: pid_t, responsePipe: String, sessionID: String, sessionLabel: String)
    case dismiss(sessionID: String)
    case register(sessionID: String, label: String)
    case unregister(sessionID: String)
    case version
    case quit

    init?(jsonLine data: Data) {
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            return nil
        }

        switch payload.action {
        case "show":
            let msg = payload.message ?? "Hello World"
            let agt = payload.agent ?? ""
            let dur = payload.duration ?? AppConfig.defaultDisplayDuration
            let p = pid_t(payload.pid ?? 0)
            let inter = payload.interactive ?? false
            let tb = payload.terminal_bundle ?? ""
            let tm = payload.tab_marker ?? ""
            let tp = payload.tty_path ?? ""
            let conv = payload.conversation ?? ""
            let rp = payload.response_pipe ?? ""
            let sid = payload.session_id ?? ""
            let slabel = payload.session_label ?? ""
            self = .show(message: msg, agent: agt, duration: dur, pid: p, interactive: inter, terminalBundle: tb, tabMarker: tm, ttyPath: tp, conversation: conv, responsePipe: rp, sessionID: sid, sessionLabel: slabel)
        case "permission":
            self = .permission(
                tool: payload.tool ?? "Unknown",
                command: payload.message ?? "",
                agent: payload.agent ?? "",
                pid: pid_t(payload.pid ?? 0),
                responsePipe: payload.response_pipe ?? "",
                suggestions: payload.permission_suggestions ?? [],
                sessionID: payload.session_id ?? "",
                sessionLabel: payload.session_label ?? ""
            )
        case "elicitation":
            guard let elicitation = payload.elicitation else { return nil }
            self = .elicitation(
                question: elicitation,
                agent: payload.agent ?? "",
                pid: pid_t(payload.pid ?? 0),
                responsePipe: payload.response_pipe ?? "",
                sessionID: payload.session_id ?? "",
                sessionLabel: payload.session_label ?? ""
            )
        case "dismiss":
            self = .dismiss(sessionID: payload.session_id ?? "")
        case "register":
            self = .register(sessionID: payload.session_id ?? "", label: payload.session_label ?? "")
        case "unregister":
            self = .unregister(sessionID: payload.session_id ?? "")
        case "version":
            self = .version
        case "quit":
            self = .quit
        default:
            return nil
        }
    }
}

private struct Payload: Decodable {
    let action: String
    let message: String?
    let agent: String?
    let duration: TimeInterval?
    let pid: Int?
    let interactive: Bool?
    let terminal_bundle: String?
    let tab_marker: String?
    let tty_path: String?
    let conversation: String?
    let tool: String?
    let response_pipe: String?
    let session_id: String?
    let session_label: String?
    let permission_suggestions: [PermissionSuggestion]?
    let elicitation: Elicitation?
}
