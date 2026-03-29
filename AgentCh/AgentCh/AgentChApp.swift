import SwiftUI

@main
struct AgentChApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("AgentCh", systemImage: "bubble.left.and.bubble.right.fill") {
            Text("AgentCh is running")
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtraStyle(.menu)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar-only app — dock icon hidden via Info.plist LSUIElement
    }
}
