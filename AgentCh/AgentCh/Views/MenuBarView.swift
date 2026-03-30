import SwiftUI

struct MenuBarView: View {
    @ObservedObject var sessionManager: SessionManager
    @ObservedObject var screenManager: ScreenManager
    @AppStorage("httpPort") var httpPort: Int = 27182
    @AppStorage("hooksDisabled") var hooksDisabled: Bool = false
    @State private var hooksInstalled: Bool = false

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

        Text("Hooks: \(hookStatusText)")

        if hooksInstalled {
            Button(hooksDisabled ? "Enable Hooks" : "Disable Hooks") {
                hooksDisabled.toggle()
                NotificationCenter.default.post(name: .agentChHooksToggled, object: nil)
            }
            Button("Uninstall Hooks") {
                uninstallHooks()
            }
        } else {
            Button("Install Hooks") {
                installHooks()
            }
        }

        Divider()

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
        .onAppear {
            hooksInstalled = HookManager.checkInstalled(port: UInt16(httpPort))
        }
    }

    private var hookStatusText: String {
        if !hooksInstalled { return "Not Installed" }
        return hooksDisabled ? "Installed & Disabled" : "Installed & Enabled"
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

    private func installHooks() {
        do {
            try HookManager.install(port: UInt16(httpPort))
            hooksInstalled = true
        } catch {
            print("Failed to install hooks: \(error)")
        }
    }

    private func uninstallHooks() {
        do {
            try HookManager.uninstall(port: UInt16(httpPort))
            hooksInstalled = false
        } catch {
            print("Failed to uninstall hooks: \(error)")
        }
    }
}
