import AppKit
import SwiftUI

final class PillHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        // Let SwiftUI handle hit testing — if super.hitTest returns a view,
        // it means the point is over an interactive SwiftUI element (the pill).
        // Otherwise return nil so the click passes through the transparent window.
        let result = super.hitTest(point)
        // If the result is self (the hosting view background), treat as pass-through
        if result === self {
            return nil
        }
        return result
    }
}
