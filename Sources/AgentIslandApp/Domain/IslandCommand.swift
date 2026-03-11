import Foundation

enum IslandCommand {
    case show(message: String, agent: String, duration: TimeInterval, pid: pid_t, interactive: Bool, terminalBundle: String, tabMarker: String, ttyPath: String)
    case dismiss
    case quit

    init?(jsonLine data: Data) {
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            return nil
        }

        switch payload.action {
        case "show":
            self = .show(
                message: payload.message ?? "Hello World",
                agent: payload.agent ?? "",
                duration: payload.duration ?? AppConfig.defaultDisplayDuration,
                pid: pid_t(payload.pid ?? 0),
                interactive: payload.interactive ?? false,
                terminalBundle: payload.terminal_bundle ?? "",
                tabMarker: payload.tab_marker ?? "",
                ttyPath: payload.tty_path ?? ""
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
}
