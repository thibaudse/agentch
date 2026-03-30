import AppKit
import ApplicationServices

struct TerminalFocuser {

    /// Focus the terminal window/tab running the given session.
    static func focus(session: Session) {
        let folderName = URL(fileURLWithPath: session.cwd).lastPathComponent

        // Find the terminal app by walking up from Claude's PID
        if let claudePid = session.termPid,
           let terminalPid = findTerminalPid(from: claudePid) {
            let app = NSRunningApplication(processIdentifier: pid_t(terminalPid))
            app?.activate()

            // Use AX API to find and raise the right window/tab
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusWindowAndTab(pid: pid_t(terminalPid), matching: folderName)
            }
            return
        }

        // Fallback: try known terminal by TERM_PROGRAM
        if let termProgram = session.termProgram,
           let bundleID = knownBundleIDs[termProgram],
           let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
            app.activate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusWindowAndTab(pid: app.processIdentifier, matching: folderName)
            }
            return
        }
    }

    // MARK: - Process tree walking

    /// Walk up from a PID to find the first GUI app (the terminal).
    private static func findTerminalPid(from pid: Int) -> Int? {
        var current = pid
        for _ in 0..<15 {
            let parent = parentPid(of: current)
            if parent <= 1 { break }

            // Check if this process is a GUI app
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

    // MARK: - Accessibility API (universal window/tab focus)

    /// Find the window matching the folder name and raise it. Also try to select the right tab.
    private static func focusWindowAndTab(pid: pid_t, matching substring: String) {
        let appElement = AXUIElementCreateApplication(pid)

        guard let windows = axAttribute(appElement, kAXWindowsAttribute) as? [AXUIElement] else { return }

        // First pass: find a window whose title contains the folder name
        for window in windows {
            if let title = axAttribute(window, kAXTitleAttribute) as? String,
               title.localizedCaseInsensitiveContains(substring) {
                AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                selectTabMatching(in: window, substring: substring)
                return
            }
        }

        // Second pass: check tabs inside each window
        for window in windows {
            if selectTabMatching(in: window, substring: substring) {
                AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                return
            }
        }

        // Last resort: just raise the first window
        if let first = windows.first {
            AXUIElementPerformAction(first, kAXRaiseAction as CFString)
        }
    }

    /// Try to find and select a tab matching the substring. Returns true if found.
    @discardableResult
    private static func selectTabMatching(in window: AXUIElement, substring: String) -> Bool {
        // Look for tab groups (AXTabGroup role)
        guard let children = axAttribute(window, kAXChildrenAttribute) as? [AXUIElement] else { return false }

        for child in children {
            if let role = axAttribute(child, kAXRoleAttribute) as? String, role == "AXTabGroup" {
                if let tabs = axAttribute(child, kAXTabsAttribute) as? [AXUIElement] {
                    for tab in tabs {
                        if let title = axAttribute(tab, kAXTitleAttribute) as? String,
                           title.localizedCaseInsensitiveContains(substring) {
                            AXUIElementPerformAction(tab, kAXPressAction as CFString)
                            return true
                        }
                    }
                }
                // Also try AXChildren of the tab group
                if let tabChildren = axAttribute(child, kAXChildrenAttribute) as? [AXUIElement] {
                    for tab in tabChildren {
                        if let title = axAttribute(tab, kAXTitleAttribute) as? String,
                           title.localizedCaseInsensitiveContains(substring) {
                            AXUIElementPerformAction(tab, kAXPressAction as CFString)
                            return true
                        }
                    }
                }
            }
        }

        // Recurse into children (some apps nest tab groups deeper)
        for child in children {
            if selectTabMatching(in: child, substring: substring) {
                return true
            }
        }

        return false
    }

    /// Helper to read an AX attribute.
    private static func axAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        return value
    }

    // MARK: - Known terminals

    private static let knownBundleIDs: [String: String] = [
        "Apple_Terminal": "com.apple.Terminal",
        "iTerm.app": "com.googlecode.iterm2",
        "WarpTerminal": "dev.warp.Warp-Stable",
        "vscode": "com.microsoft.VSCode",
        "cursor": "com.todesktop.230313mzl4w4u92",
        "kitty": "net.kovidgoyal.kitty",
        "alacritty": "org.alacritty",
        "ghostty": "com.mitchellh.ghostty",
    ]
}
