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
    private var previousWindowID: CGWindowID?
    private var tabMarker: String = ""
    private var ttyPath: String = ""
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
        interactive: Bool = false,
        terminalBundle: String = "",
        tabMarker: String = "",
        ttyPath: String = "",
        conversation: String = ""
    ) {
        cancelPendingTasks()

        // Monitor the agent process — auto-dismiss if it exits
        processMonitor.monitor(pid: pid) { [weak self] in
            self?.dismiss()
        }

        let geometry = NotchGeometry.detect()
        NSLog("AgentIsland: show() message=%@", message)
        viewModel.update(message: message, agentName: agent, geometry: geometry, interactive: interactive, conversation: conversation)
        viewModel.expanded = false

        if interactive {
            viewModel.onSubmit = { [weak self] text in
                self?.handleSubmit(text: text)
            }
            viewModel.onExpandToggle = { [weak self] in
                self?.handleExpandToggle()
            }
            // Find the terminal app by bundle ID so we paste into the right window
            if !terminalBundle.isEmpty {
                previousApp = NSRunningApplication.runningApplications(withBundleIdentifier: terminalBundle).first
            }
            if previousApp == nil {
                previousApp = NSWorkspace.shared.frontmostApplication
            }
            // Store tab marker and TTY path for targeting the right tab
            self.tabMarker = tabMarker
            self.ttyPath = ttyPath
            // Also capture the window ID as fallback
            if let app = previousApp {
                previousWindowID = TerminalPaster.frontmostWindowID(of: app)
            }
            NSLog("AgentIsland: interactive — app=%@, marker=%@, tty=%@, windowID=%d",
                  previousApp?.bundleIdentifier ?? "nil", tabMarker, ttyPath, previousWindowID ?? 0)
        } else {
            viewModel.onSubmit = nil
            previousApp = nil
            previousWindowID = nil
            self.tabMarker = ""
            self.ttyPath = ""
        }

        ensurePanel()
        guard let panel else { return }

        // Use full-expanded frame for interactive mode so the panel never resizes on expand/collapse.
        // SwiftUI animates the island shape within the fixed clear panel.
        let frame = interactive
            ? geometry.windowFrame(interactive: true, fullExpanded: true)
            : geometry.windowFrame(interactive: false)
        isPresented = true
        panel.ignoresMouseEvents = false
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        topmostSpaceManager.attach(window: panel)
        startTrackingLoop()

        if interactive {
            TerminalPaster.ensureAccessibility()
            panel.acceptsKeyInput = true
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
            // After expansion animation, make the panel key so the text field can focus
            if interactive {
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms for animation
                await MainActor.run { [weak self] in
                    self?.panel?.makeKeyAndOrderFront(nil)
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
        // If a permission prompt is active and user dismisses, deny it
        if !permissionResponsePipe.isEmpty {
            handlePermissionDecision(allow: false)
            return
        }

        processMonitor.stop()
        autoDismissTask?.cancel()
        autoDismissTask = nil
        hideTask?.cancel()
        panel?.ignoresMouseEvents = true
        panel?.acceptsKeyInput = false

        let wasInteractive = viewModel.interactive
        let appToRestore = previousApp
        previousApp = nil
        previousWindowID = nil
        tabMarker = ""
        ttyPath = ""

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

    // MARK: - Permission Request

    private var permissionResponsePipe: String = ""

    func showPermission(tool: String, command: String, agent: String, pid: pid_t, responsePipe: String, suggestions: [PermissionSuggestion] = []) {
        cancelPendingTasks()

        processMonitor.monitor(pid: pid) { [weak self] in
            self?.handlePermissionDecision(allow: false)
        }

        let geometry = NotchGeometry.detect()
        NSLog("AgentIsland: showPermission() tool=%@, command=%@, pipe=%@, suggestions=%d", tool, command, responsePipe, suggestions.count)
        viewModel.updatePermission(tool: tool, command: command, agentName: agent, geometry: geometry, suggestions: suggestions)
        viewModel.expanded = false
        permissionResponsePipe = responsePipe

        viewModel.onPermissionDecision = { [weak self] allow in
            self?.handlePermissionDecision(allow: allow)
        }
        viewModel.onPermissionSuggestion = { [weak self] suggestion in
            self?.handlePermissionSuggestion(suggestion)
        }

        ensurePanel()
        guard let panel else { return }

        let frame = geometry.windowFrame(interactive: true, fullExpanded: true)
        isPresented = true
        panel.ignoresMouseEvents = false
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        topmostSpaceManager.attach(window: panel)
        startTrackingLoop()

        panel.acceptsKeyInput = true

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: AppConfig.appearDelayNanos)
            guard let self, !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.bouncy(duration: AppConfig.appearDuration)) {
                    self.viewModel.expanded = true
                }
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
            await MainActor.run { [weak self] in
                self?.panel?.makeKeyAndOrderFront(nil)
            }
        }
    }

    private func handlePermissionDecision(allow: Bool) {
        let pipe = permissionResponsePipe
        permissionResponsePipe = ""
        NSLog("AgentIsland: permission decision=%@, pipe=%@", allow ? "allow" : "deny", pipe)

        // Write decision to the FIFO so the blocking hook script can return
        if !pipe.isEmpty {
            Task.detached {
                guard let fh = FileHandle(forWritingAtPath: pipe) else {
                    NSLog("AgentIsland: Failed to open response pipe %@", pipe)
                    return
                }
                let decision = allow ? "allow\n" : "deny\n"
                fh.write(decision.data(using: .utf8)!)
                fh.closeFile()
                NSLog("AgentIsland: Wrote '%@' to pipe", allow ? "allow" : "deny")
            }
        }

        dismiss()
    }

    private func handlePermissionSuggestion(_ suggestion: PermissionSuggestion) {
        let pipe = permissionResponsePipe
        permissionResponsePipe = ""
        NSLog("AgentIsland: permission suggestion selected=%@, pipe=%@", suggestion.label, pipe)

        // Write "allow_always:<json>" so the hook script can parse the suggestion
        if !pipe.isEmpty {
            let json = suggestion.rawJSON
            Task.detached {
                guard let fh = FileHandle(forWritingAtPath: pipe) else {
                    NSLog("AgentIsland: Failed to open response pipe %@", pipe)
                    return
                }
                let msg = "allow_always:\(json)\n"
                fh.write(msg.data(using: .utf8)!)
                fh.closeFile()
                NSLog("AgentIsland: Wrote allow_always to pipe: %@", json)
            }
        }

        dismiss()
    }

    // MARK: - Expand/Collapse

    private func handleExpandToggle() {
        // Panel is already at full-expanded size — SwiftUI animates the island shape.
        // Just ensure it stays on top.
        panel?.orderFrontRegardless()
    }

    // MARK: - Input Handling

    private func handleSubmit(text: String) {
        NSLog("AgentIsland: handleSubmit text=%@, app=%@, marker=%@, tty=%@",
              text, previousApp?.localizedName ?? "nil", tabMarker, ttyPath)
        let app = previousApp
        let windowID = previousWindowID
        let marker = tabMarker
        let tty = ttyPath
        // Dismiss without restoring the terminal — we handle focus ourselves via paste
        dismissForSubmit()
        TerminalPaster.paste(text: text, into: app, windowID: windowID, tabMarker: marker, ttyPath: tty)
    }

    /// Dismiss the island without reactivating the previous terminal app.
    /// Used when submitting — TerminalPaster handles focus.
    private func dismissForSubmit() {
        processMonitor.stop()
        autoDismissTask?.cancel()
        autoDismissTask = nil
        hideTask?.cancel()
        panel?.ignoresMouseEvents = true
        panel?.acceptsKeyInput = false
        previousApp = nil
        previousWindowID = nil
        tabMarker = ""
        ttyPath = ""

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
            }
        }
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

        let targetFrame = viewModel.interactive
            ? latestGeometry.windowFrame(interactive: true, fullExpanded: true)
            : latestGeometry.windowFrame(interactive: false)

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
