import AppKit
import SwiftUI

@MainActor
final class PillPosition: ObservableObject {
    @Published var offset: CGSize = .zero
    @Published var isDragging = false

    /// Set by PillGroupView's onHover — only start drag when mouse is over pill
    var isMouseOverPill = false

    private var dragStart: CGPoint = .zero
    private var offsetAtDragStart: CGSize = .zero
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
            guard isMouseOverPill else { return event }
            isDragging = true
            return event

        case .leftMouseDragged:
            guard isDragging else { return event }
            guard let screen = NSScreen.main else { return event }
            let mouse = NSEvent.mouseLocation
            offset = clampOffset(CGSize(
                width: mouse.x - screen.frame.width / 2,
                height: screen.frame.height - mouse.y - topPadding
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
