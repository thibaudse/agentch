import Foundation

enum IslandCommand {
    case show(message: String, agent: String, duration: TimeInterval, pid: pid_t, interactive: Bool)
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
                interactive: payload.interactive ?? false
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
}
