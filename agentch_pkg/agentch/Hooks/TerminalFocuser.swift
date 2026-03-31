import AppKit
import ApplicationServices

struct TerminalFocuser {

    /// Focus the terminal tab for a session.
    static func focus(session: Session) {
        guard let claudePid = session.termPid else { return }
        guard let terminalPid = findTerminalPid(from: claudePid) else { return }
        guard let app = NSRunningApplication(processIdentifier: pid_t(terminalPid)) else { return }
        guard let appName = app.localizedName else { return }

        // Search tab titles for the stored tab title (stripped of status icons)
        let searchTerm: String
        if let tabTitle = session.tabTitle {
            // Strip leading non-ASCII status icons (⠂, ✳, etc.)
            searchTerm = String(tabTitle.drop(while: { !$0.isASCII }).trimmingCharacters(in: .whitespaces))
        } else {
            searchTerm = session.label
        }

        NSLog("[Focus] Activating %@, searching for '%@'", appName, searchTerm)

        DispatchQueue.global(qos: .userInitiated).async {
            let escaped = escapeForAppleScript(searchTerm)
            let script = """
            tell application "\(appName)" to activate
            delay 0.05
            tell application "System Events"
                tell process "\(appName)"
                    set tabGroup to first UI element of front window whose role is "AXTabGroup"
                    repeat with btn in (UI elements of tabGroup whose role is "AXRadioButton")
                        set tabName to name of btn
                        if tabName contains "\(escaped)" then
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

    /// Capture the terminal's current window title.
    /// Best called during Stop events when Claude has finished and the title is stable.
    static func captureWindowTitle(terminalPid: Int) -> String? {
        let appElement = AXUIElementCreateApplication(pid_t(terminalPid))
        guard let windows = axAttr(appElement, kAXWindowsAttribute) as? [AXUIElement],
              let window = windows.first,
              let title = axAttr(window, kAXTitleAttribute) as? String,
              !title.isEmpty else {
            return nil
        }
        return title
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

    private static func axAttr(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        return value
    }

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
