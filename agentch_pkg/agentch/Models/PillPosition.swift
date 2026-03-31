import AppKit
import SwiftUI

@MainActor
final class PillPosition: ObservableObject {
    @Published var offset: CGSize = .zero
    @Published var isDragging = false

    var isMouseOverPill = false

    private var mouseIsDown = false
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
            mouseIsDown = true
            return event

        case .leftMouseDragged:
            guard mouseIsDown else { return event }
            if !isDragging { isDragging = true }
            guard let screen = NSScreen.main else { return event }
            let mouse = NSEvent.mouseLocation
            offset = clampOffset(CGSize(
                width: mouse.x - screen.frame.width / 2,
                height: screen.frame.height - mouse.y - topPadding
            ))
            return event

        case .leftMouseUp:
            mouseIsDown = false
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

    func moveTo(_ position: PillScreenPosition) {
        guard let screen = NSScreen.main else { return }
        let margin: CGFloat = 50
        let w = screen.frame.width
        let h = screen.frame.height

        let x: CGFloat = switch position.horizontal {
        case .leading:  -w / 2 + margin
        case .center:   0
        case .trailing: w / 2 - margin
        }

        let y: CGFloat = switch position.vertical {
        case .top:    0
        case .center: h / 2 - topPadding
        case .bottom: h - topPadding - margin
        }

        offset = CGSize(width: x, height: y)
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
