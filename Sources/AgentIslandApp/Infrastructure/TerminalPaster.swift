import AppKit
import ApplicationServices
import CoreGraphics

/// Pastes text into the previously-active application by writing to the
/// system clipboard and simulating Cmd+V then Enter via CGEvent.
@MainActor
enum TerminalPaster {
    /// Prompts the user for Accessibility permissions if not already granted.
    /// Returns `true` if the app is already trusted.
    @discardableResult
    static func ensureAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func paste(text: String, into app: NSRunningApplication?) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        app?.activate()

        Task {
            try? await Task.sleep(nanoseconds: 150_000_000) // 150ms for app activation
            postKeyCombo(key: 0x09, flags: .maskCommand) // Cmd+V
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            postKey(key: 0x24) // Enter
        }
    }

    private static func postKeyCombo(key: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) else { return }
        down.flags = flags
        down.post(tap: CGEventTapLocation.cghidEventTap)
        up.post(tap: CGEventTapLocation.cghidEventTap)
    }

    private static func postKey(key: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) else { return }
        down.post(tap: CGEventTapLocation.cghidEventTap)
        up.post(tap: CGEventTapLocation.cghidEventTap)
    }
}
