import AppKit
import ApplicationServices

struct TerminalFocuser {

    static func focus(session: Session) {
        guard let claudePid = session.termPid else { return }
        guard let terminalPid = findTerminalPid(from: claudePid) else { return }
        guard let app = NSRunningApplication(processIdentifier: pid_t(terminalPid)) else { return }

        app.activate()

        // Match by stored tab title (captured at session start)
        if let tabTitle = session.tabTitle {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                selectTabByTitle(terminalPid: pid_t(terminalPid), title: tabTitle)
            }
            return
        }

        raiseFirstWindow(pid: pid_t(terminalPid))
    }

    /// Capture the currently active tab title for the terminal owning this Claude PID.
    /// Call this at SessionStart when the user's tab is still likely active.
    static func captureActiveTabTitle(claudePid: Int) -> String? {
        guard let terminalPid = findTerminalPid(from: claudePid) else { return nil }
        let appElement = AXUIElementCreateApplication(pid_t(terminalPid))
        guard let windows = axAttr(appElement, kAXWindowsAttribute) as? [AXUIElement],
              let window = windows.first else { return nil }

        // The window title typically matches the active tab title
        if let title = axAttr(window, kAXTitleAttribute) as? String, !title.isEmpty {
            NSLog("[Focus] Captured tab title: '%@'", title)
            return title
        }
        return nil
    }

    // MARK: - Tab selection by title

    private static func selectTabByTitle(terminalPid: pid_t, title: String) {
        let appElement = AXUIElementCreateApplication(terminalPid)
        guard let windows = axAttr(appElement, kAXWindowsAttribute) as? [AXUIElement],
              let window = windows.first,
              let tabs = findTabButtons(in: window) else {
            raiseFirstWindow(pid: terminalPid)
            return
        }

        // Find the tab whose title matches (exact or contains)
        for (index, tab) in tabs.enumerated() {
            if let tabTitle = axAttr(tab, kAXTitleAttribute) as? String {
                // Strip leading status icons (⠂, ✳, etc.) for comparison
                let cleanTab = tabTitle.trimmingCharacters(in: .whitespaces)
                    .drop(while: { !$0.isASCII })
                    .trimmingCharacters(in: .whitespaces)
                let cleanTarget = title.trimmingCharacters(in: .whitespaces)
                    .drop(while: { !$0.isASCII })
                    .trimmingCharacters(in: .whitespaces)

                if cleanTab == cleanTarget || tabTitle.contains(cleanTarget) || cleanTab.contains(cleanTarget) {
                    NSLog("[Focus] Matched tab %d: '%@'", index, tabTitle)
                    AXUIElementPerformAction(tab, kAXPressAction as CFString)
                    AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                    return
                }
            }
        }

        NSLog("[Focus] No tab title match for '%@'", title)
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
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

    // MARK: - AX helpers

    private static func findTabButtons(in element: AXUIElement) -> [AXUIElement]? {
        guard let children = axAttr(element, kAXChildrenAttribute) as? [AXUIElement] else { return nil }
        for child in children {
            if (axAttr(child, kAXRoleAttribute) as? String) == "AXTabGroup" {
                if let tabChildren = axAttr(child, kAXChildrenAttribute) as? [AXUIElement] {
                    let buttons = tabChildren.filter {
                        (axAttr($0, kAXRoleAttribute) as? String) == "AXRadioButton"
                    }
                    if !buttons.isEmpty { return buttons }
                }
            }
        }
        for child in children {
            if let found = findTabButtons(in: child) { return found }
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
}
