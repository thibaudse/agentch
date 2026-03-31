import AppKit
import SwiftUI

@MainActor
final class PillPosition: ObservableObject {
    @Published var offset: CGSize = .zero
    @Published var isDragging = false

    var topPadding: CGFloat {
        let screen = NSScreen.main ?? NSScreen.screens.first
        return max(screen?.safeAreaInsets.top ?? 8, 8) + 10
    }

    init() {
        loadOffset()
    }

    func onDragChanged(_ translation: CGSize) {
        isDragging = true
        offset = clampOffset(CGSize(
            width: dragStartOffset.width + translation.width,
            height: dragStartOffset.height + translation.height
        ))
    }

    func onDragEnded() {
        isDragging = false
        saveOffset()
    }

    func onDragStarted() {
        dragStartOffset = offset
    }

    private var dragStartOffset: CGSize = .zero

    private func loadOffset() {
        if let w = UserDefaults.standard.object(forKey: "pillOffsetW") as? CGFloat,
           let h = UserDefaults.standard.object(forKey: "pillOffsetH") as? CGFloat {
            offset = CGSize(width: w, height: h)
        }
    }

    private func saveOffset() {
        UserDefaults.standard.set(offset.width, forKey: "pillOffsetW")
        UserDefaults.standard.set(offset.height, forKey: "pillOffsetH")
    }

    func resetToDefault() {
        offset = .zero
        saveOffset()
    }

    /// Clamp offset so the pill stays within screen bounds.
    private func clampOffset(_ raw: CGSize) -> CGSize {
        guard let screen = NSScreen.main else { return raw }
        let margin: CGFloat = 40
        let menuBar = screen.safeAreaInsets.top
        let maxW = screen.frame.width / 2 - margin
        let maxUp = -(topPadding - menuBar - margin)
        let maxDown = screen.frame.height - topPadding - margin

        return CGSize(
            width: min(max(raw.width, -maxW), maxW),
            height: min(max(raw.height, maxUp), maxDown)
        )
    }
}
