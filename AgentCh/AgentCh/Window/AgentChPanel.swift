import AppKit

final class AgentChPanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        isFloatingPanel = true
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        // Mouse events are filtered by PillHostingView's hitTest override —
        // it returns nil for non-pill areas, making them click-through
        ignoresMouseEvents = false
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
            .ignoresCycle,
        ]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func coverScreen() {
        guard let screen = NSScreen.main else { return }
        setFrame(screen.frame, display: true)
    }
}
