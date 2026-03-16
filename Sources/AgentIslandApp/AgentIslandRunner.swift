import AppKit
import Foundation

public enum AgentIslandRunner {
    @MainActor
    public static func run() {
        if CommandLine.arguments.contains("--version") {
            print(AgentchVersion.current)
            return
        }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
