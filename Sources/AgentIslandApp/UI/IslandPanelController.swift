import AppKit
import SwiftUI

private final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

@MainActor
final class IslandPanelController: NSObject {
    private let viewModel = IslandViewModel()
    private let topmostSpaceManager = TopmostSpaceManager()

    private var panel: OverlayPanel?
    private var autoDismissTask: Task<Void, Never>?
    private var hideTask: Task<Void, Never>?
    private var trackingTask: Task<Void, Never>?

    override init() {
        super.init()
        installObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
        trackingTask?.cancel()
    }

    func show(message: String, agent: String, duration: TimeInterval = AppConfig.defaultDisplayDuration) {
        cancelPendingTasks()

        let geometry = NotchGeometry.detect()
        viewModel.update(message: message, agentName: agent, geometry: geometry)
        viewModel.expanded = false

        ensurePanel()
        guard let panel else { return }

        panel.setFrame(geometry.windowFrame, display: true)
        panel.orderFrontRegardless()
        topmostSpaceManager.attach(window: panel)
        startTrackingLoop()

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: AppConfig.appearDelayNanos)
            guard let self, !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.bouncy(duration: AppConfig.appearDuration)) {
                    self.viewModel.expanded = true
                }
            }
        }

        if duration > 0 {
            autoDismissTask = Task { [weak self] in
                let delay = UInt64(max(duration, 0) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: delay)
                guard let self, !Task.isCancelled else { return }
                self.dismiss()
            }
        }
    }

    func dismiss() {
        autoDismissTask?.cancel()
        autoDismissTask = nil
        hideTask?.cancel()

        withAnimation(.smooth(duration: AppConfig.disappearDuration)) {
            viewModel.expanded = false
        }

        hideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: AppConfig.hideDelayNanos)
            guard let self, !Task.isCancelled else { return }
            await MainActor.run {
                guard !self.viewModel.expanded else { return }
                guard let panel = self.panel else { return }
                self.topmostSpaceManager.detach(window: panel)
                panel.orderOut(nil)
                self.stopTrackingLoop()
            }
        }
    }

    @objc private func handleSystemLayoutChange(_: Notification) {
        refreshGeometry(force: true)
    }

    private func ensurePanel() {
        guard panel == nil else { return }

        let view = IslandView(model: viewModel) { [weak self] in
            self?.dismiss()
        }

        let hostingView = NSHostingView(rootView: view)
        let panel = OverlayPanel(
            contentRect: viewModel.geometry.windowFrame,
            styleMask: [.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow],
            backing: .buffered,
            defer: false
        )

        panel.level = .mainMenu + 3
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.fullScreenAuxiliary, .stationary, .canJoinAllSpaces, .ignoresCycle]
        panel.contentView = hostingView

        self.panel = panel
    }

    private func startTrackingLoop() {
        trackingTask?.cancel()
        trackingTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                self.refreshGeometry(force: false)
                try? await Task.sleep(nanoseconds: AppConfig.trackingIntervalNanos)
            }
        }
    }

    private func stopTrackingLoop() {
        trackingTask?.cancel()
        trackingTask = nil
    }

    private func refreshGeometry(force: Bool) {
        guard let panel else { return }
        guard panel.isVisible || force else { return }

        let latestGeometry = NotchGeometry.detect()
        if latestGeometry != viewModel.geometry {
            viewModel.geometry = latestGeometry
        }

        if panel.frame != latestGeometry.windowFrame {
            panel.setFrame(latestGeometry.windowFrame, display: true)
        }

        panel.orderFrontRegardless()
        topmostSpaceManager.attach(window: panel)
    }

    private func installObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSystemLayoutChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSystemLayoutChange(_:)),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleSystemLayoutChange(_:)),
            name: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleSystemLayoutChange(_:)),
            name: Notification.Name("com.apple.screenIsLocked"),
            object: nil
        )
    }

    private func cancelPendingTasks() {
        autoDismissTask?.cancel()
        autoDismissTask = nil
        hideTask?.cancel()
        hideTask = nil
    }
}
