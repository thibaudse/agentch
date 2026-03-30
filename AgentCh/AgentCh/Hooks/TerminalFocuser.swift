import AppKit
import ApplicationServices

struct TerminalFocuser {

    static func focus(session: Session) {
        guard let claudePid = session.termPid else { return }
        guard let terminalPid = findTerminalPid(from: claudePid) else { return }
        guard let app = NSRunningApplication(processIdentifier: pid_t(terminalPid)) else { return }

        app.activate()

        guard let tty = session.tty else {
            raiseFirstWindow(pid: pid_t(terminalPid))
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            selectTabByTTY(terminalPid: terminalPid, targetTTY: tty)
        }
    }

    // MARK: - Tab selection by TTY

    private static func selectTabByTTY(terminalPid: Int, targetTTY: String) {
        // Get AX tab buttons (visual order, left to right)
        let appElement = AXUIElementCreateApplication(pid_t(terminalPid))
        guard let windows = axAttr(appElement, kAXWindowsAttribute) as? [AXUIElement],
              let window = windows.first,
              let tabs = findTabButtons(in: window),
              tabs.count > 1 else {
            raiseFirstWindow(pid: pid_t(terminalPid))
            return
        }

        // Get direct children of terminal sorted by PID (= creation order = tab order)
        let tabPids = childPids(of: terminalPid).sorted()

        // Map each child PID to its TTY
        var ttyToIndex: [String: Int] = [:]
        for (index, pid) in tabPids.enumerated() {
            if let tty = ttyOf(pid: pid) {
                ttyToIndex[tty] = index
            }
        }

        NSLog("[Focus] TTY map: %@, target: %@", String(describing: ttyToIndex), targetTTY)

        if let tabIndex = ttyToIndex[targetTTY], tabIndex < tabs.count {
            NSLog("[Focus] Selecting tab %d for TTY %@", tabIndex, targetTTY)
            AXUIElementPerformAction(tabs[tabIndex], kAXPressAction as CFString)
        }

        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
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

    private static func ttyOf(pid: Int) -> String? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, Int32(pid)]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { return nil }
        let dev = info.kp_eproc.e_tdev
        if dev == 0 || dev == -1 { return nil }
        let minor = dev & 0xffffff
        return String(format: "ttys%03d", minor)
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
