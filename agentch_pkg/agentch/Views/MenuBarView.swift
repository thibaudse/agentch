import SwiftUI

struct MenuBarView: View {
    @ObservedObject var sessionManager: SessionManager

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
}
