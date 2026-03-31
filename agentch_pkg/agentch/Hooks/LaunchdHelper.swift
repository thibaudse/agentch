import Foundation

struct LaunchdHelper {
    static let plistPath = NSHomeDirectory() + "/Library/LaunchAgents/com.agentch.plist"
    static let label = "com.agentch"

    static func install() {
        let binaryPath = ProcessInfo.processInfo.arguments[0]

        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(binaryPath)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
            <key>StandardErrorPath</key>
            <string>/tmp/agentch.log</string>
        </dict>
        </plist>
        """

        let dir = (plistPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        // Unload existing
        let _ = shell("/bin/launchctl", ["bootout", "gui/\(getuid())", plistPath])

        // Write and load
        try? plist.write(toFile: plistPath, atomically: true, encoding: .utf8)
        let result = shell("/bin/launchctl", ["bootstrap", "gui/\(getuid())", plistPath])

        if result == 0 {
            print("agentch will start automatically on login.")
        } else {
            print("Failed to install launch agent. You can start manually with 'agentch'.")
        }
    }

    static func uninstall() {
        let _ = shell("/bin/launchctl", ["bootout", "gui/\(getuid())", plistPath])
        try? FileManager.default.removeItem(atPath: plistPath)
        print("agentch removed from login items.")
    }

    @discardableResult
    private static func shell(_ command: String, _ args: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = args
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
}
