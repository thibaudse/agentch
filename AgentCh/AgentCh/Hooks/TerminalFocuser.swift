import AppKit
import ApplicationServices

struct TerminalFocuser {

    static func focus(session: Session) {
        guard let claudePid = session.termPid else {
            NSLog("[Focus] No PID for session %@", session.id)
            return
        }

        // Walk up from Claude PID to find the terminal app
        guard let terminalPid = findTerminalPid(from: claudePid) else {
            NSLog("[Focus] No terminal found for PID %d", claudePid)
            return
        }

        guard let app = NSRunningApplication(processIdentifier: pid_t(terminalPid)) else {
            NSLog("[Focus] No app for terminal PID %d", terminalPid)
            return
        }

        NSLog("[Focus] Activating %@ (PID %d)", app.localizedName ?? "?", terminalPid)
        app.activate()

        // Find which direct child of the terminal owns our Claude process (= which tab)
        let directChild = findDirectChildOfTerminal(claudePid: claudePid, terminalPid: terminalPid)
        if let directChild {
            // Get all direct children of terminal (each = a tab), sorted by PID as proxy for tab order
            let allTabPids = childPids(of: terminalPid).sorted()
            if let tabIndex = allTabPids.firstIndex(of: directChild) {
                NSLog("[Focus] Tab index: %d (child PID %d out of %d tabs)", tabIndex, directChild, allTabPids.count)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    selectTab(index: tabIndex, terminalPid: pid_t(terminalPid))
                }
                return
            }
        }

        NSLog("[Focus] Could not determine tab, just raising window")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            raiseFirstWindow(pid: pid_t(terminalPid))
        }
    }

    // MARK: - Process tree

    private static func findTerminalPid(from pid: Int) -> Int? {
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

    /// Find the direct child of the terminal that's an ancestor of Claude.
    private static func findDirectChildOfTerminal(claudePid: Int, terminalPid: Int) -> Int? {
        var current = claudePid
        var previous = claudePid
        for _ in 0..<15 {
            let parent = parentPid(of: current)
            if parent == terminalPid {
                return current
            }
            if parent <= 1 { break }
            previous = current
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

    private static func childPids(of pid: Int) -> [Int] {
        var size = 0
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        sysctl(&mib, 3, nil, &size, nil, 0)
        let count = size / MemoryLayout<kinfo_proc>.stride
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: count)
        sysctl(&mib, 3, &procs, &size, nil, 0)
        let actualCount = size / MemoryLayout<kinfo_proc>.stride
        return procs[0..<actualCount]
            .filter { Int($0.kp_eproc.e_ppid) == pid }
            .map { Int($0.kp_proc.p_pid) }
    }

    // MARK: - Accessibility: tab selection

    private static func selectTab(index: Int, terminalPid: pid_t) {
        let appElement = AXUIElementCreateApplication(terminalPid)
        guard let windows = axAttr(appElement, kAXWindowsAttribute) as? [AXUIElement],
              let window = windows.first else {
            NSLog("[Focus] No AX windows")
            return
        }

        // Find AXTabGroup and its AXRadioButton children
        if let tabs = findTabButtons(in: window) {
            NSLog("[Focus] Found %d tab buttons, selecting index %d", tabs.count, index)
            if index < tabs.count {
                AXUIElementPerformAction(tabs[index], kAXPressAction as CFString)
            }
        }

        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
    }

    private static func findTabButtons(in element: AXUIElement) -> [AXUIElement]? {
        guard let children = axAttr(element, kAXChildrenAttribute) as? [AXUIElement] else { return nil }

        for child in children {
            let role = axAttr(child, kAXRoleAttribute) as? String ?? ""
            if role == "AXTabGroup" {
                // Collect AXRadioButton children (these are the tabs)
                if let tabChildren = axAttr(child, kAXChildrenAttribute) as? [AXUIElement] {
                    let buttons = tabChildren.filter {
                        (axAttr($0, kAXRoleAttribute) as? String) == "AXRadioButton"
                    }
                    if !buttons.isEmpty { return buttons }
                }
            }
        }

        // Recurse
        for child in children {
            if let found = findTabButtons(in: child) {
                return found
            }
        }
        return nil
    }

    private static func raiseFirstWindow(pid: pid_t) {
        let appElement = AXUIElementCreateApplication(pid)
        if let windows = axAttr(appElement, kAXWindowsAttribute) as? [AXUIElement],
           let first = windows.first {
            AXUIElementPerformAction(first, kAXRaiseAction as CFString)
        }
    }

    private static func axAttr(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        return value
    }

    private static let knownBundleIDs: [String: String] = [
        "Apple_Terminal": "com.apple.Terminal",
        "iTerm.app": "com.googlecode.iterm2",
        "WarpTerminal": "dev.warp.Warp-Stable",
        "vscode": "com.microsoft.VSCode",
        "cursor": "com.todesktop.230313mzl4w4u92",
        "ghostty": "com.mitchellh.ghostty",
    ]
}
