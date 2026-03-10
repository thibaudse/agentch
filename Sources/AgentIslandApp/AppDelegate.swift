import AppKit
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let panelController = IslandPanelController()
    private var socketServer: UnixSocketServer?
    private var signalSources: [DispatchSourceSignal] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installSignalHandlers()
        startSocketServer()
        NSLog("AgentIsland: Ready")
    }

    func applicationWillTerminate(_ notification: Notification) {
        socketServer?.stop()
    }

    private func startSocketServer() {
        let server = UnixSocketServer(socketPath: AppConfig.socketPath) { [weak self] command in
            Task { @MainActor in
                self?.handle(command)
            }
        }

        do {
            try server.start()
            socketServer = server
            NSLog("AgentIsland: Listening on \(AppConfig.socketPath)")
        } catch {
            NSLog("AgentIsland: Failed to start socket server: \(String(describing: error))")
            NSApp.terminate(nil)
        }
    }

    private func handle(_ command: IslandCommand) {
        switch command {
        case let .show(message, agent, duration, pid):
            panelController.show(message: message, agent: agent, duration: duration, pid: pid)
        case .dismiss:
            panelController.dismiss()
        case .quit:
            NSApp.terminate(nil)
        }
    }

    private func installSignalHandlers() {
        signal(SIGTERM, SIG_IGN)
        signal(SIGINT, SIG_IGN)

        let sigterm = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        sigterm.setEventHandler {
            NSApp.terminate(nil)
        }
        sigterm.resume()

        let sigint = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        sigint.setEventHandler {
            NSApp.terminate(nil)
        }
        sigint.resume()

        signalSources = [sigterm, sigint]
    }
}
