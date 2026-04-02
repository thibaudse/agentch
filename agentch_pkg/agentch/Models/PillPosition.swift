import AppKit
import SwiftUI

@MainActor
final class PillPosition: ObservableObject {
    @Published var offset: CGSize = .zero
    @Published var isDragging = false

    var isMouseOverPill = false

    /// Set by AppDelegate when the selected screen changes
    var screen: NSScreen = NSScreen.main ?? NSScreen.screens.first!

    private var mouseIsDown = false
    private var mouseDownLocation: CGPoint = .zero
    private let minDragDistance: CGFloat = 5
    private var localMonitor: Any?

    var topPadding: CGFloat {
        max(screen.safeAreaInsets.top, 8) + 10
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
            mouseIsDown = true
            mouseDownLocation = NSEvent.mouseLocation
            return event

        case .leftMouseDragged:
            guard mouseIsDown else { return event }
            let mouse = NSEvent.mouseLocation
            if !isDragging {
                let dx = mouse.x - mouseDownLocation.x
                let dy = mouse.y - mouseDownLocation.y
                let distance = sqrt(dx * dx + dy * dy)
                guard distance >= minDragDistance else { return event }
                isDragging = true
            }
            let screen = self.screen
            offset = clampOffset(CGSize(
                width: mouse.x - screen.frame.width / 2,
                height: screen.frame.height - mouse.y - topPadding
            ))
            return event

        case .leftMouseUp:
            mouseIsDown = false
            if isDragging {
                isDragging = false
                snapToNearestPosition()
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
        moveTo(PillScreenPosition.all[1]) // Top Center
    }

    func moveTo(_ position: PillScreenPosition) {
        offset = offsetFor(position)
        saveOffset()
    }

    /// Single source of truth for computing offset from a screen position.
    func offsetFor(_ position: PillScreenPosition) -> CGSize {
        let padding = screenPadding(screen)
        let w = screen.frame.width
        let h = screen.frame.height
        let menuBar = screen.safeAreaInsets.top

        let x: CGFloat = switch position.horizontal {
        case .leading:  -w / 2 + padding
        case .center:   0
        case .trailing: w / 2 - padding
        }

        let y: CGFloat = switch position.vertical {
        case .top:    padding
        case .center: (h - menuBar) / 2 - topPadding + menuBar
        case .bottom: h - topPadding - padding
        }

        return CGSize(width: x, height: y)
    }

    /// Always snap to the nearest of the 9 positions on drag end.
    private func snapToNearestPosition() {
        var bestDist: CGFloat = .greatestFiniteMagnitude
        var bestOffset: CGSize = offset

        for pos in PillScreenPosition.all {
            let target = offsetFor(pos)
            let dx = offset.width - target.width
            let dy = offset.height - target.height
            let dist = sqrt(dx * dx + dy * dy)
            if dist < bestDist {
                bestDist = dist
                bestOffset = target
            }
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
            offset = bestOffset
        }
    }

    /// Screen-relative padding (~2% of the shorter dimension, min 12pt)
    private func screenPadding(_ screen: NSScreen) -> CGFloat {
        max(min(screen.frame.width, screen.frame.height) * 0.02, 12)
    }

    private func clampOffset(_ raw: CGSize) -> CGSize {
        let screen = self.screen
        let padding = screenPadding(screen)
        let maxW = screen.frame.width / 2 - padding
        // offset.height = 0 means pill is at topPadding. Minimum offset = padding (same as moveTo .top)
        let minH = padding
        let maxH = screen.frame.height - topPadding - padding

        return CGSize(
            width: min(max(raw.width, -maxW), maxW),
            height: min(max(raw.height, minH), maxH)
        )
    }
}

struct PillScreenPosition {
    enum H { case leading, center, trailing }
    enum V { case top, center, bottom }
    let horizontal: H
    let vertical: V
    let label: String

    static let all: [PillScreenPosition] = [
        .init(horizontal: .leading,  vertical: .top,    label: "↖ Top Left"),
        .init(horizontal: .center,   vertical: .top,    label: "↑ Top Center"),
        .init(horizontal: .trailing, vertical: .top,    label: "↗ Top Right"),
        .init(horizontal: .leading,  vertical: .center, label: "← Middle Left"),
        .init(horizontal: .center,   vertical: .center, label: "● Center"),
        .init(horizontal: .trailing, vertical: .center, label: "→ Middle Right"),
        .init(horizontal: .leading,  vertical: .bottom, label: "↙ Bottom Left"),
        .init(horizontal: .center,   vertical: .bottom, label: "↓ Bottom Center"),
        .init(horizontal: .trailing, vertical: .bottom, label: "↘ Bottom Right"),
    ]
}
