import AppKit
import ApplicationServices

struct TerminalFocuser {

    static func focus(session: Session) {
        guard let claudePid = session.termPid else { return }
        guard let terminalPid = findTerminalPid(from: claudePid) else { return }
        guard let app = NSRunningApplication(processIdentifier: pid_t(terminalPid)) else { return }
        guard let appName = app.localizedName else { return }

        // Use osascript to activate — completely external, won't fight with our panel
        let marker = "agentch:\(session.id)"
        DispatchQueue.global(qos: .userInitiated).async {
            let script: String
            // Activate app, then find and click the tab with our marker
            script = """
            tell application "\(appName)" to activate
            delay 0.05
            tell application "System Events"
                tell process "\(appName)"
                    set tabGroup to first UI element of front window whose role is "AXTabGroup"
                    repeat with btn in (UI elements of tabGroup whose role is "AXRadioButton")
                        if name of btn contains "\(marker)" then
                            click btn
                            return
                        end if
                    end repeat
                end tell
            end tell
            """
            NSLog("[Focus] Running AppleScript for marker '%@' in %@", marker, appName)
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
                if let error {
                    NSLog("[Focus] AppleScript error: %@", error)
                }
            }
        }
    }

    // MARK: - Tab selection

    private static func selectTab(terminalPid: pid_t, session: Session) {
        let appElement = AXUIElementCreateApplication(terminalPid)
        guard let windows = axAttr(appElement, kAXWindowsAttribute) as? [AXUIElement],
              let window = windows.first else {
            return
        }

        guard let tabs = findTabButtons(in: window), tabs.count > 1 else {
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
            return
        }

        // Look for the tab whose title contains our marker: "agentch:SESSION_ID"
        let marker = "agentch:\(session.id)"
        NSLog("[Focus] Searching %d tabs for marker '%@'", tabs.count, marker)

        for (index, tab) in tabs.enumerated() {
            guard let title = axAttr(tab, kAXTitleAttribute) as? String else { continue }
            NSLog("[Focus] Tab %d: '%@'", index, title)

            if title.contains(marker) {
                NSLog("[Focus] Matched tab %d", index)
                AXUIElementPerformAction(tab, kAXPressAction as CFString)
                AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                return
            }
        }

        NSLog("[Focus] No marker match")
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

    private static func axAttr(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        return value
    }

    static func captureActiveTabTitle(claudePid: Int) -> String? { nil }
}
