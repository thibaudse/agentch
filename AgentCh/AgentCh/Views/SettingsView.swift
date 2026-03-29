import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("httpPort") var httpPort: Int = 27182
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        updateLaunchAtLogin(newValue)
                    }
            }

            Section("Server") {
                TextField("HTTP Port", value: $httpPort, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                Text("Requires app restart to take effect")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Pill Position") {
                Button("Reset to Default") {
                    UserDefaults.standard.removeObject(forKey: "pillPositionX")
                    UserDefaults.standard.removeObject(forKey: "pillPositionY")
                }
            }

            Section("Hooks") {
                Button("Reinstall Hooks") {
                    try? HookManager.install(port: UInt16(httpPort))
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 350, height: 300)
        .padding()
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

    func showWindow() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
        let hostingView = NSHostingView(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 300),
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
