import AppKit
import SwiftUI

private final class OverlayPanel: NSPanel {
    var acceptsKeyInput = false

    override var canBecomeKey: Bool { acceptsKeyInput }
    override var canBecomeMain: Bool { false }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

@MainActor
final class IslandPanelController: NSObject {
    private let viewModel = IslandViewModel()
    private let topmostSpaceManager = TopmostSpaceManager()
    private let processMonitor = ProcessMonitor()

    private var panel: OverlayPanel?
    private var isPresented = false
    private var previousApp: NSRunningApplication?
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

    func show(
        message: String,
        agent: String,
        duration: TimeInterval = AppConfig.defaultDisplayDuration,
        pid: pid_t = 0,
        interactive: Bool = false
    ) {
        cancelPendingTasks()

        // Monitor the agent process — auto-dismiss if it exits
        processMonitor.monitor(pid: pid) { [weak self] in
            self?.dismiss()
        }

        let geometry = NotchGeometry.detect()
        viewModel.update(message: message, agentName: agent, geometry: geometry, interactive: interactive)
        viewModel.expanded = false

        if interactive {
            viewModel.onSubmit = { [weak self] text in
                self?.handleSubmit(text: text)
            }
            previousApp = NSWorkspace.shared.frontmostApplication
        } else {
            viewModel.onSubmit = nil
            previousApp = nil
        }

        ensurePanel()
        guard let panel else { return }

        let frame = geometry.windowFrame(interactive: interactive)
        isPresented = true
        panel.ignoresMouseEvents = false
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        topmostSpaceManager.attach(window: panel)
        startTrackingLoop()

        if interactive {
            TerminalPaster.ensureAccessibility()
            panel.acceptsKeyInput = true
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.acceptsKeyInput = false
        }

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
        processMonitor.stop()
        autoDismissTask?.cancel()
        autoDismissTask = nil
        hideTask?.cancel()
        panel?.ignoresMouseEvents = true
        panel?.acceptsKeyInput = false

        let wasInteractive = viewModel.interactive
        let appToRestore = previousApp
        previousApp = nil

        withAnimation(.smooth(duration: AppConfig.disappearDuration)) {
            viewModel.expanded = false
        }

        hideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: AppConfig.hideDelayNanos)
            guard let self, !Task.isCancelled else { return }
            await MainActor.run {
                guard !self.viewModel.expanded else { return }
                guard let panel = self.panel else { return }
                self.isPresented = false
                self.topmostSpaceManager.detach(window: panel)
                panel.orderOut(nil)
                self.stopTrackingLoop()

                if wasInteractive, let app = appToRestore {
                    app.activate()
                }
            }
        }
    }

    // MARK: - Input Handling

    private func handleSubmit(text: String) {
        let app = previousApp
        dismiss()
        TerminalPaster.paste(text: text, into: app)
    }

    // MARK: - System Layout

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
            contentRect: viewModel.geometry.windowFrame(),
            styleMask: [.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow],
            backing: .buffered,
            defer: false
        )

        panel.level = AppConfig.panelWindowLevel
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.fullScreenAuxiliary, .stationary, .canJoinAllSpaces, .ignoresCycle]
        panel.contentView = hostingView

        self.panel = panel
    }

    private func refreshGeometry(force: Bool) {
        guard let panel else { return }

        let latestGeometry = NotchGeometry.detect()
        if latestGeometry != viewModel.geometry {
            viewModel.geometry = latestGeometry
        }

        let targetFrame = latestGeometry.windowFrame(interactive: viewModel.interactive)

        if !isPresented {
            if force, panel.frame != targetFrame {
                panel.setFrame(targetFrame, display: false)
            }
            return
        }

        if panel.frame != targetFrame {
            panel.setFrame(targetFrame, display: true)
        }
        panel.level = AppConfig.panelWindowLevel
        panel.orderFrontRegardless()
        topmostSpaceManager.attach(window: panel)
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

    private func installObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSystemLayoutChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSystemLayoutChange(_:)),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSystemLayoutChange(_:)),
            name: NSApplication.didBecomeActiveNotification,
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
        processMonitor.stop()
        autoDismissTask?.cancel()
        autoDismissTask = nil
        hideTask?.cancel()
        hideTask = nil
    }
}
