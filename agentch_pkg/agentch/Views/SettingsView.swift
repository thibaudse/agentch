import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var pillPosition: PillPosition
    @ObservedObject var screenManager: ScreenManager
    @AppStorage("httpPort") var httpPort: Int = 27182
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false

    var body: some View {
        Text("Settings placeholder")
            .frame(width: 450, height: 580)
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = !enabled
        }
    }
}

@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?
    var pillPosition: PillPosition?
    var screenManager: ScreenManager?

    func showWindow() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        guard let pillPosition, let screenManager else { return }

        let settingsView = SettingsView(pillPosition: pillPosition, screenManager: screenManager)
        let hostingView = NSHostingView(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 580),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "AgentCh Settings"
        window.contentView = hostingView
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }
}
