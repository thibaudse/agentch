import AppKit

struct TerminalFocuser {
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

    static func focus(session: Session) {
        if let termProgram = session.termProgram,
           let bundleID = bundleIDs[termProgram] {
            if activateApp(bundleID: bundleID, termProgram: termProgram, cwd: session.cwd) { return }
        }

        if let pid = session.termPid {
            if activateByProcessTree(pid: pid) { return }
        }

        for (term, bundleID) in [("Apple_Terminal", "com.apple.Terminal"),
                                  ("iTerm.app", "com.googlecode.iterm2"),
                                  ("ghostty", "com.mitchellh.ghostty")] {
            if activateApp(bundleID: bundleID, termProgram: term, cwd: session.cwd) { return }
        }
    }

    @discardableResult
    private static func activateApp(bundleID: String, termProgram: String, cwd: String) -> Bool {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
            return false
        }

        app.activate()

        let folderName = URL(fileURLWithPath: cwd).lastPathComponent

        switch termProgram {
        case "Apple_Terminal":
            focusTerminalTab(matching: folderName)
        case "iTerm.app":
            focusITermTab(matching: folderName)
        case "ghostty":
            focusGhosttyTab(matching: folderName)
        case "vscode", "cursor":
            focusVSCodeWindow(appName: app.localizedName ?? "Code", matching: folderName)
        default:
            focusWindowByTitle(appName: app.localizedName ?? "", matching: folderName)
        }

        return true
    }

    // MARK: - Terminal.app

    private static func focusTerminalTab(matching substring: String) {
        let script = """
        tell application "Terminal"
            repeat with w in windows
                repeat with t in tabs of w
                    if custom title of t contains "\(substring)" or name of t contains "\(substring)" then
                        set selected tab of w to t
                        set index of w to 1
                        activate
                        return
                    end if
                end repeat
            end repeat
        end tell
        """
        runAppleScript(script)
    }

    // MARK: - iTerm2

    private static func focusITermTab(matching substring: String) {
        let script = """
        tell application "iTerm2"
            repeat with w in windows
                repeat with t in tabs of w
                    repeat with s in sessions of t
                        if name of s contains "\(substring)" or profile name of s contains "\(substring)" then
                            select t
                            select s
                            set index of w to 1
                            activate
                            return
                        end if
                    end repeat
                end repeat
            end repeat
        end tell
        """
        runAppleScript(script)
    }

    // MARK: - Ghostty

    private static func focusGhosttyTab(matching substring: String) {
        // Ghostty doesn't have rich AppleScript — use System Events to find window + tab
        let script = """
        tell application "System Events"
            tell process "Ghostty"
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
        runAppleScript(script)
    }

    // MARK: - VS Code / Cursor

    private static func focusVSCodeWindow(appName: String, matching substring: String) {
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
        runAppleScript(script)
    }

    // MARK: - Generic fallback

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
        runAppleScript(script)
    }

    // MARK: - Process tree

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

    // MARK: - Helpers

    private static func runAppleScript(_ source: String) {
        if let script = NSAppleScript(source: source) {
            var error: NSDictionary?
            script.executeAndReturnError(&error)
        }
    }
}
