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
            // NSScreen y is bottom-up, SwiftUI offset y is top-down
            let dy = -(current.y - dragStart.y)
            offset = CGSize(
                width: offsetAtDragStart.width + dx,
                height: offsetAtDragStart.height + dy
            )
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
}
