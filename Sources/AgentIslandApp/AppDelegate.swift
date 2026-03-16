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
        panelController.showIdle()
        NSLog("agentch: Ready")
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
            NSLog("agentch: Listening on \(AppConfig.socketPath)")
        } catch {
            NSLog("agentch: Failed to start socket server: \(String(describing: error))")
            NSApp.terminate(nil)
        }
    }

    private func handle(_ command: IslandCommand) {
        switch command {
        case let .show(message, agent, duration, pid, interactive, terminalBundle, tabMarker, ttyPath, conversation, responsePipe, sessionID, sessionLabel):
            panelController.show(message: message, agent: agent, duration: duration, pid: pid, interactive: interactive, terminalBundle: terminalBundle, tabMarker: tabMarker, ttyPath: ttyPath, conversation: conversation, responsePipe: responsePipe, sessionID: sessionID, sessionLabel: sessionLabel)
        case let .permission(tool, command, agent, pid, responsePipe, suggestions, sessionID, sessionLabel):
            panelController.showPermission(tool: tool, command: command, agent: agent, pid: pid, responsePipe: responsePipe, suggestions: suggestions, sessionID: sessionID, sessionLabel: sessionLabel)
        case let .elicitation(question, agent, pid, responsePipe, sessionID, sessionLabel):
            panelController.showElicitation(question: question, agent: agent, pid: pid, responsePipe: responsePipe, sessionID: sessionID, sessionLabel: sessionLabel)
        case let .dismiss(sessionID):
            panelController.dismiss(sessionID: sessionID)
        case let .register(sessionID):
            panelController.registerSession(sessionID)
        case let .unregister(sessionID):
            panelController.unregisterSession(sessionID)
        case .version:
            break  // Handled synchronously in UnixSocketServer
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
