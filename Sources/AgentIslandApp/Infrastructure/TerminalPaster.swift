import AppKit
import ApplicationServices
import CoreGraphics

/// Serializes paste operations so two overlapping pastes don't race on the clipboard.
private actor PasteQueue {
    private var pending: [CheckedContinuation<Void, Never>] = []
    private var busy = false

    func acquire() async {
        if busy {
            await withCheckedContinuation { cont in
                pending.append(cont)
            }
        }
        busy = true
    }

    func release() {
        if let next = pending.first {
            pending.removeFirst()
            next.resume()
        } else {
            busy = false
        }
    }
}

/// Global paste queue — ensures only one clipboard paste happens at a time.
private let pasteQueue = PasteQueue()

/// Sends text to the correct terminal tab. Tries three strategies in order:
/// 1. **TIOCSTI** — inject chars directly into the TTY input queue (no focus switch)
/// 2. **Clipboard + brief focus switch** — Cmd+V, then restore focus automatically
@MainActor
enum TerminalPaster {
    @discardableResult
    static func ensureAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Find the frontmost on-screen window of the given app (fallback).
    static func frontmostWindowID(of app: NSRunningApplication) -> CGWindowID? {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[CFString: Any]] else { return nil }

        for info in windowList {
            guard let ownerPID = info[kCGWindowOwnerPID] as? pid_t,
                  ownerPID == app.processIdentifier,
                  let windowID = info[kCGWindowNumber] as? CGWindowID,
                  let layer = info[kCGWindowLayer] as? Int, layer == 0
            else { continue }
            return windowID
        }
        return nil
    }

    /// Send text to the correct terminal tab.
    static func paste(
        text: String,
        into app: NSRunningApplication?,
        windowID: CGWindowID? = nil,
        tabMarker: String = "",
        ttyPath: String = ""
    ) {
        NSLog("AgentIsland: paste() — text=%@, app=%@, marker=%@, tty=%@, trusted=%d",
              text, app?.bundleIdentifier ?? "nil", tabMarker, ttyPath, AXIsProcessTrusted() ? 1 : 0)

        // Strategy 1: Direct TTY injection (no focus switch needed)
        if !ttyPath.isEmpty {
            let injected = injectViaTTY(text: text + "\n", ttyPath: ttyPath)
            if injected {
                NSLog("AgentIsland: TIOCSTI injection succeeded — no focus switch needed")
                if !ttyPath.isEmpty { clearTabTitle(ttyPath: ttyPath) }
                return
            }
            NSLog("AgentIsland: TIOCSTI failed, falling back to clipboard paste")
        }

        // Strategy 2: Clipboard + brief focus switch + auto-restore
        pasteViaClipboard(text: text, app: app, tabMarker: tabMarker, ttyPath: ttyPath)
    }

    // MARK: - Strategy 1: Direct TTY Injection

    /// Inject text into the terminal's input queue via TIOCSTI ioctl.
    /// This sends characters as if the user typed them — no focus switch needed.
    /// Returns false if the ioctl is not supported (modern macOS may block it).
    private static func injectViaTTY(text: String, ttyPath: String) -> Bool {
        let fd = open(ttyPath, O_RDWR)
        guard fd >= 0 else {
            NSLog("AgentIsland: Cannot open TTY %@ (errno %d)", ttyPath, errno)
            return false
        }
        defer { close(fd) }

        // TIOCSTI = _IOW('t', 114, char) = 0x80017472
        let TIOCSTI: UInt = 0x80017472

        for byte in text.utf8 {
            var b = byte
            let result = ioctl(fd, TIOCSTI, &b)
            if result != 0 {
                NSLog("AgentIsland: TIOCSTI failed at byte %d (errno %d)", byte, errno)
                return false
            }
        }
        return true
    }

    // MARK: - Strategy 2: Clipboard + Focus Switch

    /// Save the current clipboard contents so we can restore them after pasting.
    private static func saveClipboard() -> (String?, [NSPasteboardItem])? {
        let pasteboard = NSPasteboard.general
        guard let items = pasteboard.pasteboardItems, !items.isEmpty else { return nil }

        // Deep-copy all items and their type data, since pasteboardItems are invalidated on clearContents
        var copiedItems: [NSPasteboardItem] = []
        for item in items {
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            copiedItems.append(copy)
        }
        let changeCount = pasteboard.changeCount
        NSLog("AgentIsland: Saved clipboard (%d items, changeCount=%d)", copiedItems.count, changeCount)
        return (nil, copiedItems)
    }

    /// Restore clipboard contents that were saved before pasting.
    private static func restoreClipboard(savedItems: [NSPasteboardItem]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(savedItems)
        NSLog("AgentIsland: Restored clipboard (%d items)", savedItems.count)
    }

    private static func pasteViaClipboard(
        text: String,
        app: NSRunningApplication?,
        tabMarker: String,
        ttyPath: String
    ) {
        Task { @MainActor in
            // Serialize paste operations so overlapping pastes don't race on the clipboard
            await pasteQueue.acquire()
            defer { Task { await pasteQueue.release() } }

            // Remember the user's current app so we can restore focus
            let userApp = NSWorkspace.shared.frontmostApplication

            // Save current clipboard so we can restore it after pasting
            let savedClipboard = saveClipboard()

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)

            // Activate the terminal
            if let app {
                app.activate(from: NSRunningApplication.current)
            }

            // Select the right tab
            if let app, !tabMarker.isEmpty {
                let found = selectTab(matching: tabMarker, pid: app.processIdentifier)
                NSLog("AgentIsland: selectTab(marker=%@) → %d", tabMarker, found ? 1 : 0)
            }

            try? await Task.sleep(nanoseconds: 600_000_000) // 600ms for activation + tab switch

            // Debug: verify clipboard and frontmost app before pasting
            let clipCheck = NSPasteboard.general.string(forType: .string) ?? "<nil>"
            let frontApp = NSWorkspace.shared.frontmostApplication
            NSLog("AgentIsland: PRE-PASTE clipboard=%@, frontApp=%@, expectedApp=%@",
                  clipCheck.prefix(60).description,
                  frontApp?.bundleIdentifier ?? "nil",
                  app?.bundleIdentifier ?? "nil")

            NSLog("AgentIsland: Posting Cmd+V via AppleScript")
            sendPasteKeystroke()
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms between keys
            NSLog("AgentIsland: Posting Enter via AppleScript")
            sendReturnKeystroke()

            // Wait for Ghostty to fully process the keystrokes before switching away
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms

            // Restore the user's original clipboard contents
            if let (_, items) = savedClipboard, !items.isEmpty {
                restoreClipboard(savedItems: items)
            } else {
                // Nothing was on the clipboard before — just clear our paste text
                pasteboard.clearContents()
                NSLog("AgentIsland: Cleared clipboard (was empty before paste)")
            }

            if !ttyPath.isEmpty { clearTabTitle(ttyPath: ttyPath) }
            if let userApp, userApp.bundleIdentifier != app?.bundleIdentifier {
                userApp.activate(from: NSRunningApplication.current)
                NSLog("AgentIsland: Restored focus to %@", userApp.localizedName ?? "?")
            }
            NSLog("AgentIsland: Clipboard paste complete, clipboard restored")
        }
    }

    // MARK: - Tab Selection via Accessibility

    private static func selectTab(matching marker: String, pid: pid_t) -> Bool {
        let appElement = AXUIElementCreateApplication(pid)

        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else {
            NSLog("AgentIsland: Failed to get AX windows for pid %d", pid)
            return false
        }

        for window in windows {
            if let found = findAndSelectTab(in: window, matching: marker) {
                return found
            }
            if titleMatches(element: window, marker: marker) {
                AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                return true
            }
        }

        NSLog("AgentIsland: No tab found matching marker %@", marker)
        return false
    }

    private static func findAndSelectTab(in element: AXUIElement, matching marker: String) -> Bool? {
        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        let role = roleRef as? String ?? ""

        if role == "AXTabGroup" {
            var tabsRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXTabsAttribute as CFString, &tabsRef) == .success,
               let tabs = tabsRef as? [AXUIElement] {
                for tab in tabs {
                    if titleMatches(element: tab, marker: marker) {
                        AXUIElementPerformAction(tab, kAXPressAction as CFString)
                        NSLog("AgentIsland: Selected tab matching marker in tab group")
                        return true
                    }
                }
            }
        }

        if role == "AXRadioButton" || role == "AXTab" {
            if titleMatches(element: element, marker: marker) {
                AXUIElementPerformAction(element, kAXPressAction as CFString)
                NSLog("AgentIsland: Pressed tab element matching marker")
                return true
            }
        }

        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                if let result = findAndSelectTab(in: child, matching: marker) {
                    return result
                }
            }
        }

        return nil
    }

    private static func titleMatches(element: AXUIElement, marker: String) -> Bool {
        var ref: CFTypeRef?
        for attr in [kAXTitleAttribute, kAXValueAttribute, kAXDescription] as [CFString] {
            if AXUIElementCopyAttributeValue(element, attr, &ref) == .success,
               let str = ref as? String, str.contains(marker) {
                return true
            }
        }
        return false
    }

    // MARK: - TTY Title Cleanup

    private static func clearTabTitle(ttyPath: String) {
        guard let fh = FileHandle(forWritingAtPath: ttyPath) else { return }
        if let data = "\u{1b}]2;\u{07}".data(using: .utf8) {
            fh.write(data)
        }
        fh.closeFile()
        NSLog("AgentIsland: Cleared tab title via %@", ttyPath)
    }

    // MARK: - Key Posting via AppleScript (more reliable with Ghostty/GPU terminals)

    /// Use System Events to send Cmd+V — works where CGEvent sometimes doesn't.
    private static func sendPasteKeystroke() {
        let script = NSAppleScript(source: """
            tell application "System Events"
                keystroke "v" using command down
            end tell
            """)
        var error: NSDictionary?
        script?.executeAndReturnError(&error)
        if let error {
            NSLog("AgentIsland: AppleScript Cmd+V error: %@", error)
        }
    }

    /// Use System Events to send Return key.
    private static func sendReturnKeystroke() {
        let script = NSAppleScript(source: """
            tell application "System Events"
                key code 36
            end tell
            """)
        var error: NSDictionary?
        script?.executeAndReturnError(&error)
        if let error {
            NSLog("AgentIsland: AppleScript Return error: %@", error)
        }
    }
}
