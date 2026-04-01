import SwiftUI

struct MenuBarView: View {
    @ObservedObject var sessionManager: SessionManager
    @ObservedObject var screenManager: ScreenManager
    @ObservedObject var pillPosition: PillPosition
    @AppStorage("httpPort") var httpPort: Int = 27182
    @AppStorage("hooksDisabled") var hooksDisabled: Bool = false

    var body: some View {
        if sessionManager.sessions.isEmpty {
            Text("No active sessions")
        } else {
            ForEach(sessionManager.sessions) { session in
                Button {
                    TerminalFocuser.focus(session: session)
                } label: {
                    Text("\(statusEmoji(session.status)) \(session.label) — \(statusText(session.status))")
                }
            }
        }

        Divider()

        Menu("Hooks") {
            ForEach(AgentHookConfig.all, id: \.label) { agent in
                let installed = HookManager.checkInstalled(port: UInt16(httpPort), agent: agent)
                Button("\(agent.label): \(installed ? "Installed" : "Not Installed")") {
                    if installed {
                        try? HookManager.uninstall(agent: agent)
                    } else {
                        try? HookManager.install(port: UInt16(httpPort), agent: agent)
                    }
                }
            }
            Divider()
            Button("Install All") {
                HookManager.installAll(port: UInt16(httpPort))
            }
            Button("Uninstall All") {
                HookManager.uninstallAll()
            }
        }

        if !hooksDisabled {
            Button("Disable Hooks") {
                hooksDisabled.toggle()
                NotificationCenter.default.post(name: .agentChHooksToggled, object: nil)
            }
        } else {
            Button("Enable Hooks") {
                hooksDisabled.toggle()
                NotificationCenter.default.post(name: .agentChHooksToggled, object: nil)
            }
        }

        Divider()

        Menu("Position") {
            ForEach(PillScreenPosition.all, id: \.label) { pos in
                Button(pos.label) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        pillPosition.moveTo(pos)
                    }
                }
            }
        }

        Menu("Display: \(screenManager.screenNames.first(where: { $0.index == screenManager.selectedScreenIndex })?.name ?? "Unknown")") {
            ForEach(screenManager.screenNames, id: \.index) { screen in
                Button(screen.name) {
                    screenManager.selectedScreenIndex = screen.index
                }
            }
        }

        Divider()

        Button("Settings...") {
            SettingsWindowController.shared.showWindow()
        }

        Button("Quit AgentCh") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private func statusEmoji(_ status: SessionStatus) -> String {
        switch status {
        case .thinking: return "🟢"
        case .waiting: return "🟠"
        case .idle: return "⚪"
        case .error: return "🔴"
        }
    }

    private func statusText(_ status: SessionStatus) -> String {
        switch status {
        case .thinking: return "working"
        case .waiting: return "needs input"
        case .idle: return "idle"
        case .error: return "error"
        }
    }

    // Removed — hooks managed per-agent via HookManager.install/uninstall(agent:)
}
