import AppKit
import SwiftUI

final class PillHostingView<Content: View>: NSHostingView<Content> {
    private var pillFrame: CGRect = .zero

    func updatePillFrame(_ frame: CGRect) {
        self.pillFrame = frame
        window?.ignoresMouseEvents = false
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if pillFrame.contains(point) {
            return super.hitTest(point)
        }
        return nil
    }
}
