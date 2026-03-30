import AppKit

struct TerminalFocuser {
    /// Known terminal app bundle identifiers by TERM_PROGRAM value.
    private static let bundleIDs: [String: String] = [
        "Apple_Terminal": "com.apple.Terminal",
        "iTerm.app": "com.googlecode.iterm2",
        "WarpTerminal": "dev.warp.Warp-Stable",
        "vscode": "com.microsoft.VSCode",
        "cursor": "com.todesktop.230313mzl4w4u92",
        "Hyper": "co.zeit.hyper",
        "kitty": "net.kovidgoyal.kitty",
        "alacritty": "org.alacritty",
        "ghostty": "com.mitchellh.ghostty",
    ]

    /// Focus the terminal window running the given session.
    static func focus(session: Session) {
        // Strategy 1: Find terminal by TERM_PROGRAM
        if let termProgram = session.termProgram,
           let bundleID = bundleIDs[termProgram] {
            if activateApp(bundleID: bundleID, cwd: session.cwd) { return }
        }

        // Strategy 2: Walk up process tree from the hook's PID to find a GUI app
        if let pid = session.termPid {
            if activateByProcessTree(pid: pid) { return }
        }

        // Strategy 3: Try common terminals, look for matching window title
        for bundleID in ["com.apple.Terminal", "com.googlecode.iterm2", "dev.warp.Warp-Stable", "com.mitchellh.ghostty"] {
            if activateApp(bundleID: bundleID, cwd: session.cwd) { return }
        }
    }

    /// Activate an app by bundle ID and try to focus a window matching the cwd.
    @discardableResult
    private static func activateApp(bundleID: String, cwd: String) -> Bool {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
            return false
        }

        app.activate()

        // Try AppleScript to focus the right window/tab by title containing cwd
        let folderName = URL(fileURLWithPath: cwd).lastPathComponent
        focusWindowByTitle(appName: app.localizedName ?? "", matching: folderName)

        return true
    }

    /// Walk up process tree to find a GUI app ancestor.
    @discardableResult
    private static func activateByProcessTree(pid: Int) -> Bool {
        var currentPid = pid
        for _ in 0..<10 {
            let parentPid = getParentPid(currentPid)
            if parentPid <= 1 { break }

            if let app = NSRunningApplication(processIdentifier: pid_t(parentPid)),
               app.activationPolicy == .regular {
                app.activate()
                return true
            }
            currentPid = parentPid
        }
        return false
    }

    private static func getParentPid(_ pid: Int) -> Int {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-o", "ppid=", "-p", "\(pid)"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return Int(str) ?? 0
        } catch {
            return 0
        }
    }

    /// Use AppleScript to focus a window whose title contains the given string.
    private static func focusWindowByTitle(appName: String, matching substring: String) {
        let script = """
        tell application "System Events"
            tell process "\(appName)"
                set frontmost to true
                repeat with w in windows
                    if name of w contains "\(substring)" then
                        perform action "AXRaise" of w
                        return
                    end if
                end repeat
            end tell
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
}
