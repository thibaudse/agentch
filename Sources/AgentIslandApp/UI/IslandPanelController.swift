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
    private var responsePipe: String = ""
    private var autoDismissTask: Task<Void, Never>?
    private var hideTask: Task<Void, Never>?
    nonisolated(unsafe) private var trackingTask: Task<Void, Never>?
    private var lastContentHeight: CGFloat = 0
    private var suppressPanelResize = false
    private var resizeEnableTask: Task<Void, Never>?

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
        conversation: String = "",
        responsePipe: String = ""
    ) {
        cancelPendingTasks()

        // Monitor the agent process — auto-dismiss if it exits
        processMonitor.monitor(pid: pid) { [weak self] in
            self?.dismiss()
        }

        let geometry = NotchGeometry.detect()
        NSLog("agentch: show() message=%@", message)
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
            self.responsePipe = responsePipe
            // Also capture the window ID as fallback
            if let app = previousApp {
                previousWindowID = TerminalPaster.frontmostWindowID(of: app)
            }
            NSLog("agentch: interactive — app=%@, marker=%@, tty=%@, windowID=%d, pipe=%@",
                  previousApp?.bundleIdentifier ?? "nil", tabMarker, ttyPath, previousWindowID ?? 0, responsePipe)
        } else {
            viewModel.onSubmit = nil
            previousApp = nil
            previousWindowID = nil
            self.tabMarker = ""
            self.ttyPath = ""
            self.responsePipe = ""
        }

        // Track content height so the panel matches the island exactly
        viewModel.onContentHeightChange = { [weak self] (h: CGFloat) -> Void in
            self?.contentHeightChanged(h)
        }

        ensurePanel()
        guard let panel else { return }

        // Start with a generous frame; the content height callback will resize to fit
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
            // Only check accessibility if we'll need to paste into a terminal
            if !tabMarker.isEmpty || !ttyPath.isEmpty {
                TerminalPaster.ensureAccessibility()
            }
            panel.acceptsKeyInput = true
        } else {
            panel.acceptsKeyInput = false
        }

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: AppConfig.appearDelayNanos)
            guard let self, !Task.isCancelled else { return }
            await MainActor.run {
                // 1. Expand the window instantly (no animation) so the notch spring has room
                self.expandPanelForAnimation()
                // 2. Slight delay so the window is fully sized before the notch animates
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 16_000_000) // ~1 frame
                    guard let self else { return }
                    withAnimation(DS.Anim.notchOpen) {
                        self.viewModel.expanded = true
                    }
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

        // If a response pipe is active, write dismiss to unblock the background worker
        if !responsePipe.isEmpty {
            let pipe = responsePipe
            responsePipe = ""
            Task.detached {
                guard let fh = FileHandle(forWritingAtPath: pipe) else { return }
                fh.write("__dismiss__\n".data(using: .utf8)!)
                fh.closeFile()
                NSLog("agentch: Wrote __dismiss__ to response pipe %@", pipe)
            }
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

        // Step 1: Fade out content (quick)
        withAnimation(DS.Anim.contentOut) {
            viewModel.contentVisible = false
        }

        // Step 2: After content fades, collapse the notch shape
        hideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms for content fade
            guard let self, !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(DS.Anim.notchClose) {
                    self.viewModel.expanded = false
                }
            }

            // Step 3: After collapse animation, remove the panel
            try? await Task.sleep(nanoseconds: 320_000_000) // 320ms for notch close spring
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                guard let self else { return }
                guard !self.viewModel.expanded else { return }
                guard let panel = self.panel else { return }
                self.isPresented = false
                self.topmostSpaceManager.detach(window: panel)
                panel.orderOut(nil)
                self.stopTrackingLoop()
                // Reset contentVisible for next show
                self.viewModel.contentVisible = true

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
        NSLog("agentch: showPermission() tool=%@, command=%@, pipe=%@, suggestions=%d", tool, command, responsePipe, suggestions.count)
        viewModel.updatePermission(tool: tool, command: command, agentName: agent, geometry: geometry, suggestions: suggestions)
        viewModel.expanded = false
        permissionResponsePipe = responsePipe

        viewModel.onPermissionDecision = { [weak self] allow in
            self?.handlePermissionDecision(allow: allow)
        }
        viewModel.onPermissionSuggestion = { [weak self] suggestion in
            self?.handlePermissionSuggestion(suggestion)
        }
        viewModel.onContentHeightChange = { [weak self] (h: CGFloat) -> Void in
            self?.contentHeightChanged(h)
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
                self.expandPanelForAnimation()
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 16_000_000)
                    guard let self else { return }
                    withAnimation(DS.Anim.notchOpen) {
                        self.viewModel.expanded = true
                    }
                }
            }
        }
    }

    private func handlePermissionDecision(allow: Bool) {
        let pipe = permissionResponsePipe
        permissionResponsePipe = ""
        NSLog("agentch: permission decision=%@, pipe=%@", allow ? "allow" : "deny", pipe)

        // Write decision to the FIFO so the blocking hook script can return
        if !pipe.isEmpty {
            Task.detached {
                guard let fh = FileHandle(forWritingAtPath: pipe) else {
                    NSLog("agentch: Failed to open response pipe %@", pipe)
                    return
                }
                let decision = allow ? "allow\n" : "deny\n"
                fh.write(decision.data(using: .utf8)!)
                fh.closeFile()
                NSLog("agentch: Wrote '%@' to pipe", allow ? "allow" : "deny")
            }
        }

        dismiss()
    }

    // MARK: - Elicitation (AskUserQuestion)

    func showElicitation(question: Elicitation, agent: String, pid: pid_t, responsePipe: String) {
        cancelPendingTasks()

        processMonitor.monitor(pid: pid) { [weak self] in
            self?.handlePermissionDecision(allow: false)
        }

        let geometry = NotchGeometry.detect()
        NSLog("agentch: showElicitation() question=%@, options=%d, pipe=%@",
              question.question, question.options.count, responsePipe)
        viewModel.updateElicitation(question: question, agentName: agent, geometry: geometry)
        viewModel.expanded = false
        permissionResponsePipe = responsePipe

        viewModel.onElicitationAnswer = { [weak self] answer in
            self?.handleElicitationAnswer(answer)
        }
        viewModel.onContentHeightChange = { [weak self] (h: CGFloat) -> Void in
            self?.contentHeightChanged(h)
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
                self.expandPanelForAnimation()
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 16_000_000)
                    guard let self else { return }
                    withAnimation(DS.Anim.notchOpen) {
                        self.viewModel.expanded = true
                    }
                }
            }
        }
    }

    private func handleElicitationAnswer(_ answer: String) {
        let pipe = permissionResponsePipe
        permissionResponsePipe = ""
        NSLog("agentch: elicitation answer=%@, pipe=%@", answer, pipe)

        if !pipe.isEmpty {
            Task.detached {
                guard let fh = FileHandle(forWritingAtPath: pipe) else {
                    NSLog("agentch: Failed to open response pipe %@", pipe)
                    return
                }
                let msg = "answer:\(answer)\n"
                fh.write(msg.data(using: .utf8)!)
                fh.closeFile()
                NSLog("agentch: Wrote elicitation answer to pipe: %@", answer)
            }
        }

        dismiss()
    }

    private func handlePermissionSuggestion(_ suggestion: PermissionSuggestion) {
        let pipe = permissionResponsePipe
        permissionResponsePipe = ""
        NSLog("agentch: permission suggestion selected=%@, pipe=%@", suggestion.label, pipe)

        // Write "allow_always:<json>" so the hook script can parse the suggestion
        if !pipe.isEmpty {
            let json = suggestion.rawJSON
            Task.detached {
                guard let fh = FileHandle(forWritingAtPath: pipe) else {
                    NSLog("agentch: Failed to open response pipe %@", pipe)
                    return
                }
                let msg = "allow_always:\(json)\n"
                fh.write(msg.data(using: .utf8)!)
                fh.closeFile()
                NSLog("agentch: Wrote allow_always to pipe: %@", json)
            }
        }

        dismiss()
    }

    // MARK: - Expand/Collapse

    private func handleExpandToggle() {
        // Expand panel to max so SwiftUI has room to animate content change,
        // then shrink to fit after animation settles
        expandPanelForAnimation()
        panel?.orderFrontRegardless()
    }

    // MARK: - Panel Frame Tracking

    private func contentHeightChanged(_ height: CGFloat) {
        lastContentHeight = height
        if !suppressPanelResize {
            updatePanelFrame()
        }
    }

    /// Temporarily expand the panel to max size and suppress content-driven resizing.
    /// After the animation settles, re-enable and resize to fit.
    private func expandPanelForAnimation() {
        guard let panel, isPresented else { return }
        suppressPanelResize = true
        resizeEnableTask?.cancel()

        let geo = viewModel.geometry
        let frame = geo.windowFrame(interactive: true, fullExpanded: true)
        panel.setFrame(frame, display: true)

        resizeEnableTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms — let spring settle
            guard let self, !Task.isCancelled else { return }
            await MainActor.run {
                self.suppressPanelResize = false
                self.updatePanelFrame()
            }
        }
    }

    /// Resize the panel to exactly match the island's visible content.
    private func updatePanelFrame() {
        guard let panel, isPresented, viewModel.expanded else { return }
        let geo = viewModel.geometry
        let needsWide = viewModel.isFullExpanded || viewModel.isElicitation || viewModel.isPermission
        let width = geo.effectiveWidth(interactive: viewModel.interactive, fullExpanded: needsWide)
        let height = max(geo.notchHeight, min(lastContentHeight, geo.maxPanelHeight))
        let originX = geo.screenFrame.midX - width / 2
        let originY = geo.screenFrame.maxY - height
        let frame = CGRect(x: originX, y: originY, width: width, height: height)
        if panel.frame != frame {
            panel.setFrame(frame, display: true)
        }
    }

    // MARK: - Input Handling

    private func handleSubmit(text: String) {
        let pipe = responsePipe
        let app = previousApp
        let windowID = previousWindowID
        let marker = tabMarker
        let tty = ttyPath
        let hasTerminalInfo = !marker.isEmpty || !tty.isEmpty

        NSLog("agentch: handleSubmit text=%@, pipe=%@, app=%@, marker=%@, hasTerminal=%@",
              text, pipe, previousApp?.localizedName ?? "nil", marker, hasTerminalInfo ? "yes" : "no")

        responsePipe = ""
        dismissForSubmit()

        // Write response to FIFO — unblocks the hook script waiting on the pipe
        if !pipe.isEmpty {
            Task.detached {
                guard let fh = FileHandle(forWritingAtPath: pipe) else {
                    NSLog("agentch: Failed to open response pipe %@", pipe)
                    return
                }
                fh.write("\(text)\n".data(using: .utf8)!)
                fh.closeFile()
                NSLog("agentch: Wrote response to pipe: %@", text)
            }
        }

        // Only paste into terminal if terminal info is present (Codex/OpenCode flow).
        // For Claude Code's synchronous Stop hook, the FIFO response is all we need —
        // the hook returns decision:block with the user's text, no paste required.
        if hasTerminalInfo {
            TerminalPaster.paste(text: text, into: app, windowID: windowID, tabMarker: marker, ttyPath: tty)
        } else if let app {
            // No paste needed, but re-activate the terminal so it's in focus
            app.activate()
        }
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
        responsePipe = ""

        // Same 2-step animation as dismiss(): content fade → notch collapse → remove
        withAnimation(DS.Anim.contentOut) {
            viewModel.contentVisible = false
        }

        hideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 200_000_000) // content fade
            guard let self, !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(DS.Anim.notchClose) {
                    self.viewModel.expanded = false
                }
            }

            try? await Task.sleep(nanoseconds: 320_000_000) // notch close
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                guard let self else { return }
                guard !self.viewModel.expanded else { return }
                guard let panel = self.panel else { return }
                self.isPresented = false
                self.topmostSpaceManager.detach(window: panel)
                panel.orderOut(nil)
                self.stopTrackingLoop()
                self.viewModel.contentVisible = true
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

        if !isPresented {
            if force {
                let targetFrame = latestGeometry.windowFrame(interactive: false)
                if panel.frame != targetFrame {
                    panel.setFrame(targetFrame, display: false)
                }
            }
            return
        }

        // Use content-based frame when we have a measured height
        if lastContentHeight > 0, viewModel.expanded {
            updatePanelFrame()
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
        resizeEnableTask?.cancel()
        resizeEnableTask = nil
        suppressPanelResize = false
    }
}
