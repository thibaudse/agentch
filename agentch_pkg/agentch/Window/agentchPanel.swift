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
        level = .mainMenu + 3
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        isMovable = false
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
            .ignoresCycle,
        ]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func coverScreen(_ screen: NSScreen? = nil) {
        let target = screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let target else { return }
        setFrame(target.frame, display: true)
    }
}
