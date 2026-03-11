import Foundation

/// Represents an "always allow" suggestion from Claude Code's PermissionRequest.
/// The raw JSON is preserved so we can echo it back verbatim.
struct PermissionSuggestion: Decodable, Identifiable {
    let type: String               // e.g. "toolAlwaysAllow", "addRules"
    let tool: String?              // for toolAlwaysAllow
    let rules: [[String: String]]? // for addRules: [{"toolName":"...", "ruleContent":"..."}]

    var id: String { label }

    /// Human-readable label for the button
    var label: String {
        switch type {
        case "toolAlwaysAllow":
            return "Always allow \(tool ?? "this tool")"
        case "addRules":
            if let rules, let first = rules.first {
                let toolName = first["toolName"] ?? ""
                let rule = first["ruleContent"] ?? ""
                if !rule.isEmpty {
                    return "Allow \(toolName): \(rule)"
                }
                return "Always allow \(toolName)"
            }
            return "Always allow"
        default:
            return "Always allow"
        }
    }

    /// JSON string to pass back to the hook script
    var rawJSON: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        // Re-encode from original Decodable data isn't possible, so reconstruct
        var dict: [String: Any] = ["type": type]
        if let tool { dict["tool"] = tool }
        if let rules { dict["rules"] = rules }
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }
}

/// A question from an AskUserQuestion elicitation.
struct ElicitationOption: Decodable, Identifiable {
    let label: String
    let description: String?

    var id: String { label }
}

struct Elicitation: Decodable {
    let question: String
    let options: [ElicitationOption]
}

enum IslandCommand {
    case show(message: String, agent: String, duration: TimeInterval, pid: pid_t, interactive: Bool, terminalBundle: String, tabMarker: String, ttyPath: String, conversation: String, responsePipe: String)
    case permission(tool: String, command: String, agent: String, pid: pid_t, responsePipe: String, suggestions: [PermissionSuggestion])
    case elicitation(question: Elicitation, agent: String, pid: pid_t, responsePipe: String)
    case dismiss
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
            self = .show(message: msg, agent: agt, duration: dur, pid: p, interactive: inter, terminalBundle: tb, tabMarker: tm, ttyPath: tp, conversation: conv, responsePipe: rp)
        case "permission":
            self = .permission(
                tool: payload.tool ?? "Unknown",
                command: payload.message ?? "",
                agent: payload.agent ?? "",
                pid: pid_t(payload.pid ?? 0),
                responsePipe: payload.response_pipe ?? "",
                suggestions: payload.permission_suggestions ?? []
            )
        case "elicitation":
            guard let elicitation = payload.elicitation else { return nil }
            self = .elicitation(
                question: elicitation,
                agent: payload.agent ?? "",
                pid: pid_t(payload.pid ?? 0),
                responsePipe: payload.response_pipe ?? ""
            )
        case "dismiss":
            self = .dismiss
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
    let permission_suggestions: [PermissionSuggestion]?
    let elicitation: Elicitation?
}
