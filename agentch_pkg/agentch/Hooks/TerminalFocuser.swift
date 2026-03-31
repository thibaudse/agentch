import AppKit
import ApplicationServices

struct TerminalFocuser {

    static func focus(session: Session) {
        guard let claudePid = session.termPid else { return }
        guard let terminalPid = findTerminalPid(from: claudePid) else { return }
        guard let app = NSRunningApplication(processIdentifier: pid_t(terminalPid)) else { return }
        guard let appName = app.localizedName else { return }
        guard let tty = session.tty else {
            DispatchQueue.global(qos: .userInitiated).async {
                runAppleScript("tell application \"\(appName)\" to activate")
            }
            return
        }

        let marker = "agentch:\(session.id)"

        DispatchQueue.global(qos: .userInitiated).async {
            // 1. Set a unique title on the session's TTY
            setTerminalTitle(marker, onTTY: tty)

            // 2. Small delay for the terminal to process the escape sequence
            Thread.sleep(forTimeInterval: 0.05)

            // 3. Activate the terminal and click the tab with our marker
            let escaped = escapeForAppleScript(marker)
            let script = """
            tell application "\(appName)" to activate
            delay 0.05
            tell application "System Events"
                tell process "\(appName)"
                    set tabGroup to first UI element of front window whose role is "AXTabGroup"
                    repeat with btn in (UI elements of tabGroup whose role is "AXRadioButton")
                        if name of btn contains "\(escaped)" then
                            click btn
                            return
                        end if
                    end repeat
                end tell
            end tell
            """
            runAppleScript(script)
        }
    }

    /// Write an ANSI title escape to a specific TTY device.
    private static func setTerminalTitle(_ title: String, onTTY tty: String) {
        let path = "/dev/\(tty)"
        guard let fh = FileHandle(forWritingAtPath: path) else {
            NSLog("[Focus] Cannot open %@", path)
            return
        }
        // OSC 2 = set window title
        let escape = "\u{1b}]2;\(title)\u{07}"
        if let data = escape.data(using: .utf8) {
            fh.write(data)
        }
        fh.closeFile()
    }

    // MARK: - Process tree

    static func findTerminalPid(from pid: Int) -> Int? {
        var current = pid
        for _ in 0..<15 {
            let parent = parentPid(of: current)
            if parent <= 1 { break }
            if let app = NSRunningApplication(processIdentifier: pid_t(parent)),
               app.activationPolicy == .regular {
                return parent
            }
            current = parent
        }
        return nil
    }

    private static func parentPid(of pid: Int) -> Int {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, Int32(pid)]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { return 0 }
        return Int(info.kp_eproc.e_ppid)
    }

    // MARK: - Helpers

    private static func runAppleScript(_ source: String) {
        if let script = NSAppleScript(source: source) {
            var error: NSDictionary?
            script.executeAndReturnError(&error)
            if let error {
                NSLog("[Focus] AppleScript error: %@", error)
            }
        }
    }

    private static func escapeForAppleScript(_ str: String) -> String {
        str.replacingOccurrences(of: "\\", with: "\\\\")
           .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
