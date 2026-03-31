import AppKit
import SwiftUI

@MainActor
final class PillPosition: ObservableObject {
    @Published var offset: CGSize = .zero

    private var dragStart: CGPoint = .zero
    private var offsetAtDragStart: CGSize = .zero
    private var isDragging = false
    private var localMonitor: Any?

    var topPadding: CGFloat {
        let screen = NSScreen.main ?? NSScreen.screens.first
        return max(screen?.safeAreaInsets.top ?? 8, 8) + 10
    }

    init() {
        loadOffset()
    }

    func startMonitoring() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            self?.handleMouse(event) ?? event
        }
    }

    func stopMonitoring() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    private func handleMouse(_ event: NSEvent) -> NSEvent? {
        switch event.type {
        case .leftMouseDown:
            isDragging = true
            dragStart = NSEvent.mouseLocation
            offsetAtDragStart = offset
            return event

        case .leftMouseDragged:
            guard isDragging else { return event }
            let current = NSEvent.mouseLocation
            let dx = current.x - dragStart.x
            let dy = -(current.y - dragStart.y)
            offset = clampOffset(CGSize(
                width: offsetAtDragStart.width + dx,
                height: offsetAtDragStart.height + dy
            ))
            return event

        case .leftMouseUp:
            if isDragging {
                isDragging = false
                saveOffset()
            }
            return event

        default:
            return event
        }
    }

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
