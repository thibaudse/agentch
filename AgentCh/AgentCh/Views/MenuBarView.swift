import SwiftUI

struct MenuBarView: View {
    @ObservedObject var sessionManager: SessionManager
    @AppStorage("httpPort") var httpPort: Int = 27182
    @AppStorage("hooksDisabled") var hooksDisabled: Bool = false
    @State private var hooksInstalled: Bool = false

    var body: some View {
        if sessionManager.sessions.isEmpty {
            Text("No active sessions")
                .foregroundStyle(.secondary)
        } else {
            ForEach(sessionManager.sessions) { session in
                HStack {
                    Circle()
                        .fill(statusColor(session.status))
                        .frame(width: 8, height: 8)
                    Text(session.label)
                    Spacer()
                    Text(session.agentType.rawValue)
                        .foregroundStyle(.secondary)
                }
            }
        }

        Divider()

        Text("Hooks: \(hookStatusText)")
            .foregroundStyle(.secondary)

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

    private func statusColor(_ status: SessionStatus) -> Color {
        switch status {
        case .thinking: return .green
        case .idle: return .gray
        case .error: return .red
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
