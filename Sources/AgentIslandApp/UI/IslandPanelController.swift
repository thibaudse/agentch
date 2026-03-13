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
    private enum PendingCommand {
        case show(
            message: String,
            agent: String,
            duration: TimeInterval,
            pid: pid_t,
            interactive: Bool,
            terminalBundle: String,
            tabMarker: String,
            ttyPath: String,
            conversation: String,
            responsePipe: String,
            sessionID: String
        )
        case permission(
            tool: String,
            command: String,
            agent: String,
            pid: pid_t,
            responsePipe: String,
            suggestions: [PermissionSuggestion],
            sessionID: String
        )
        case elicitation(
            question: Elicitation,
            agent: String,
            pid: pid_t,
            responsePipe: String,
            sessionID: String
        )

        var sessionID: String {
            switch self {
            case let .show(_, _, _, _, _, _, _, _, _, _, sessionID):
                return sessionID
            case let .permission(_, _, _, _, _, _, sessionID):
                return sessionID
            case let .elicitation(_, _, _, _, sessionID):
                return sessionID
            }
        }

        var cancelPipe: String {
            switch self {
            case let .show(_, _, _, _, _, _, _, _, _, responsePipe, _):
                return responsePipe
            case let .permission(_, _, _, _, responsePipe, _, _):
                return responsePipe
            case let .elicitation(_, _, _, responsePipe, _):
                return responsePipe
            }
        }

        var cancelMessage: String {
            switch self {
            case .show:
                return "__dismiss__"
            case .permission, .elicitation:
                return "deny"
            }
        }
    }

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
    private var permissionResponsePipe: String = ""
    private var pendingCommands: [PendingCommand] = []
    private var isTransitioningOut = false
    private var activeSessionID: String = ""
    private var geometryRefreshSuspendedUntil: Date = .distantPast

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

    private var hasBlockingPromptInFlight: Bool {
        !responsePipe.isEmpty || !permissionResponsePipe.isEmpty
    }

    private var isBlockingPromptPresented: Bool {
        isPresented && (viewModel.interactive || viewModel.isPermission || viewModel.isElicitation)
    }

    private func normalizedSessionID(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isGeometryRefreshSuspended: Bool {
        Date() < geometryRefreshSuspendedUntil
    }

    private func suspendGeometryRefresh(for seconds: TimeInterval) {
        let candidate = Date().addingTimeInterval(max(0, seconds))
        if candidate > geometryRefreshSuspendedUntil {
            geometryRefreshSuspendedUntil = candidate
        }
    }

    private func hasMeaningfulGeometryChange(from old: NotchGeometry, to new: NotchGeometry) -> Bool {
        if old.hasNotch != new.hasNotch { return true }
        if abs(old.notchWidth - new.notchWidth) > 0.5 { return true }
        if abs(old.notchHeight - new.notchHeight) > 0.5 { return true }

        let oa = old.screenFrame
        let na = new.screenFrame
        if abs(oa.origin.x - na.origin.x) > 0.5 { return true }
        if abs(oa.origin.y - na.origin.y) > 0.5 { return true }
        if abs(oa.width - na.width) > 0.5 { return true }
        if abs(oa.height - na.height) > 0.5 { return true }
        return false
    }

    private func shouldUpdatePanelFrame(current: CGRect, target: CGRect) -> Bool {
        if abs(current.origin.x - target.origin.x) > 0.5 { return true }
        if abs(current.origin.y - target.origin.y) > 0.5 { return true }
        if abs(current.width - target.width) > 0.5 { return true }
        if abs(current.height - target.height) > 0.5 { return true }
        return false
    }

    private func shouldQueueBlockingCommand() -> Bool {
        isBlockingPromptPresented || hasBlockingPromptInFlight || isTransitioningOut
    }

    private func enqueue(_ command: PendingCommand) {
        let sid = normalizedSessionID(command.sessionID)
        if !sid.isEmpty,
           let index = pendingCommands.firstIndex(where: { normalizedSessionID($0.sessionID) == sid }) {
            let old = pendingCommands[index]
            writePipeMessage(old.cancelMessage, to: old.cancelPipe)
            pendingCommands[index] = command
            NSLog("agentch: replaced queued blocking command for session=%@ (pending=%d)", sid, pendingCommands.count)
            return
        }

        pendingCommands.append(command)
        NSLog("agentch: queued blocking command session=%@ (pending=%d)", sid, pendingCommands.count)
    }

    private func writePipeMessage(_ message: String, to pipe: String) {
        guard !pipe.isEmpty else { return }
        Task.detached {
            guard let fh = FileHandle(forWritingAtPath: pipe) else {
                NSLog("agentch: Failed to open queued response pipe %@", pipe)
                return
            }
            fh.write("\(message)\n".data(using: .utf8)!)
            fh.closeFile()
            NSLog("agentch: Wrote queued response '%@' to pipe %@", message, pipe)
        }
    }

    private func removeQueuedCommands(forSessionID sessionID: String) -> Int {
        let sid = normalizedSessionID(sessionID)
        guard !sid.isEmpty else { return 0 }

        let (kept, removed) = pendingCommands.reduce(into: ([PendingCommand](), [PendingCommand]())) { acc, command in
            if normalizedSessionID(command.sessionID) == sid {
                acc.1.append(command)
            } else {
                acc.0.append(command)
            }
        }

        pendingCommands = kept
        for command in removed {
            writePipeMessage(command.cancelMessage, to: command.cancelPipe)
        }

        if !removed.isEmpty {
            NSLog("agentch: removed queued commands for session=%@ count=%d", sid, removed.count)
        }

        return removed.count
    }

    private func presentNextQueuedCommandIfNeeded() {
        guard !shouldQueueBlockingCommand() else { return }
        guard !pendingCommands.isEmpty else { return }

        let next = pendingCommands.removeFirst()
        NSLog("agentch: presenting queued command (remaining=%d)", pendingCommands.count)

        switch next {
        case let .show(message, agent, duration, pid, interactive, terminalBundle, tabMarker, ttyPath, conversation, responsePipe, sessionID):
            show(
                message: message,
                agent: agent,
                duration: duration,
                pid: pid,
                interactive: interactive,
                terminalBundle: terminalBundle,
                tabMarker: tabMarker,
                ttyPath: ttyPath,
                conversation: conversation,
                responsePipe: responsePipe,
                sessionID: sessionID
            )
        case let .permission(tool, command, agent, pid, responsePipe, suggestions, sessionID):
            showPermission(
                tool: tool,
                command: command,
                agent: agent,
                pid: pid,
                responsePipe: responsePipe,
                suggestions: suggestions,
                sessionID: sessionID
            )
        case let .elicitation(question, agent, pid, responsePipe, sessionID):
            showElicitation(
                question: question,
                agent: agent,
                pid: pid,
                responsePipe: responsePipe,
                sessionID: sessionID
            )
        }
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
        responsePipe: String = "",
        sessionID: String = ""
    ) {
        let sid = normalizedSessionID(sessionID)

        if interactive, shouldQueueBlockingCommand() {
            enqueue(
                PendingCommand.show(
                    message: message,
                    agent: agent,
                    duration: duration,
                    pid: pid,
                    interactive: interactive,
                    terminalBundle: terminalBundle,
                    tabMarker: tabMarker,
                    ttyPath: ttyPath,
                    conversation: conversation,
                    responsePipe: responsePipe,
                    sessionID: sid
                )
            )
            return
        }

        cancelPendingTasks()
        isTransitioningOut = false

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
            self.activeSessionID = sid
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
            self.activeSessionID = ""
        }

        // Track content height for click-through hit testing bounds.
        viewModel.onContentHeightChange = { [weak self] (h: CGFloat) -> Void in
            self?.contentHeightChanged(h)
        }

        ensurePanel()
        guard let panel else { return }

        // Keep the hosting window fixed to the screen bounds to avoid
        // panel-frame redraw artifacts during notch/content animations.
        let frame = geometry.screenFrame
        isPresented = true
        panel.ignoresMouseEvents = true
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        topmostSpaceManager.attach(window: panel)
        startTrackingLoop()
        updatePanelInteractivity()

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
                self.suspendGeometryRefresh(for: 0.9)
                // Keep panel frame fixed; only animate SwiftUI notch/content.
                self.expandPanelForAnimation()
                // Slight delay so first layout pass settles before the notch animates.
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

    func dismiss(sessionID: String = "") {
        let targetSessionID = normalizedSessionID(sessionID)
        let currentSessionID = normalizedSessionID(activeSessionID)

        // Session-scoped dismiss for multi-session Claude queues.
        // If the target is queued (not currently visible), cancel just that queued item.
        if !targetSessionID.isEmpty, targetSessionID != currentSessionID {
            _ = removeQueuedCommands(forSessionID: targetSessionID)
            return
        }

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
        isTransitioningOut = true
        suspendGeometryRefresh(for: 0.9)
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
            try? await Task.sleep(nanoseconds: AppConfig.hideDelayNanos)
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.hideTask = nil
                self.isTransitioningOut = false

                if !self.viewModel.expanded, let panel = self.panel {
                    self.isPresented = false
                    self.topmostSpaceManager.detach(window: panel)
                    panel.orderOut(nil)
                    self.stopTrackingLoop()
                    // Reset contentVisible for next show
                    self.viewModel.contentVisible = true
                }

                self.activeSessionID = ""

                if wasInteractive, let app = appToRestore {
                    app.activate()
                }

                self.presentNextQueuedCommandIfNeeded()
            }
        }
    }

    // MARK: - Permission Request

    func showPermission(
        tool: String,
        command: String,
        agent: String,
        pid: pid_t,
        responsePipe: String,
        suggestions: [PermissionSuggestion] = [],
        sessionID: String = ""
    ) {
        let sid = normalizedSessionID(sessionID)

        if shouldQueueBlockingCommand() {
            enqueue(
                PendingCommand.permission(
                    tool: tool,
                    command: command,
                    agent: agent,
                    pid: pid,
                    responsePipe: responsePipe,
                    suggestions: suggestions,
                    sessionID: sid
                )
            )
            return
        }

        cancelPendingTasks()
        isTransitioningOut = false

        processMonitor.monitor(pid: pid) { [weak self] in
            self?.handlePermissionDecision(allow: false)
        }

        let geometry = NotchGeometry.detect()
        NSLog("agentch: showPermission() tool=%@, command=%@, pipe=%@, suggestions=%d", tool, command, responsePipe, suggestions.count)
        viewModel.updatePermission(tool: tool, command: command, agentName: agent, geometry: geometry, suggestions: suggestions)
        viewModel.expanded = false
        permissionResponsePipe = responsePipe
        activeSessionID = sid

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

        let frame = geometry.screenFrame
        isPresented = true
        panel.ignoresMouseEvents = true
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        topmostSpaceManager.attach(window: panel)
        startTrackingLoop()
        updatePanelInteractivity()

        panel.acceptsKeyInput = true

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: AppConfig.appearDelayNanos)
            guard let self, !Task.isCancelled else { return }
            await MainActor.run {
                self.suspendGeometryRefresh(for: 0.9)
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

    func showElicitation(
        question: Elicitation,
        agent: String,
        pid: pid_t,
        responsePipe: String,
        sessionID: String = ""
    ) {
        let sid = normalizedSessionID(sessionID)

        if shouldQueueBlockingCommand() {
            enqueue(
                PendingCommand.elicitation(
                    question: question,
                    agent: agent,
                    pid: pid,
                    responsePipe: responsePipe,
                    sessionID: sid
                )
            )
            return
        }

        cancelPendingTasks()
        isTransitioningOut = false

        processMonitor.monitor(pid: pid) { [weak self] in
            self?.handlePermissionDecision(allow: false)
        }

        let geometry = NotchGeometry.detect()
        NSLog("agentch: showElicitation() question=%@, options=%d, pipe=%@",
              question.question, question.options.count, responsePipe)
        viewModel.updateElicitation(question: question, agentName: agent, geometry: geometry)
        viewModel.expanded = false
        permissionResponsePipe = responsePipe
        activeSessionID = sid

        viewModel.onElicitationAnswer = { [weak self] answer in
            self?.handleElicitationAnswer(answer)
        }
        viewModel.onContentHeightChange = { [weak self] (h: CGFloat) -> Void in
            self?.contentHeightChanged(h)
        }

        ensurePanel()
        guard let panel else { return }

        let frame = geometry.screenFrame
        isPresented = true
        panel.ignoresMouseEvents = true
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        topmostSpaceManager.attach(window: panel)
        startTrackingLoop()
        updatePanelInteractivity()

        panel.acceptsKeyInput = true

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: AppConfig.appearDelayNanos)
            guard let self, !Task.isCancelled else { return }
            await MainActor.run {
                self.suspendGeometryRefresh(for: 0.9)
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
        // Keep the panel frame fixed; only SwiftUI animates.
        expandPanelForAnimation()
        panel?.orderFrontRegardless()
    }

    // MARK: - Panel Frame Tracking

    private func contentHeightChanged(_ height: CGFloat) {
        lastContentHeight = height
        updatePanelInteractivity()
    }

    /// Panel is fixed to the full screen bounds to avoid frame resize artifacts.
    private func expandPanelForAnimation() {
        updatePanelInteractivity()
    }

    private func islandScreenFrame() -> CGRect {
        let geo = viewModel.geometry
        let needsWide = viewModel.isFullExpanded || viewModel.isElicitation || viewModel.isPermission
        let width = viewModel.expanded
            ? geo.effectiveWidth(interactive: viewModel.interactive, fullExpanded: needsWide)
            : geo.notchWidth

        let measuredHeight = max(
            geo.notchHeight,
            min(lastContentHeight > 0 ? lastContentHeight : geo.effectiveHeight(interactive: viewModel.interactive), geo.maxPanelHeight)
        )
        let height = viewModel.expanded ? measuredHeight : geo.notchHeight
        let originX = geo.screenFrame.midX - width / 2
        let originY = geo.screenFrame.maxY - height
        return CGRect(x: originX, y: originY, width: width, height: height)
    }

    /// Keep the full-screen panel click-through except over the island bounds.
    private func updatePanelInteractivity() {
        guard let panel else { return }
        guard isPresented, viewModel.contentVisible else {
            panel.ignoresMouseEvents = true
            return
        }

        let hitFrame = islandScreenFrame().insetBy(dx: -2, dy: -2)
        panel.ignoresMouseEvents = !hitFrame.contains(NSEvent.mouseLocation)
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

        // Only paste into terminal if terminal info is present.
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
        isTransitioningOut = true
        suspendGeometryRefresh(for: 0.9)
        panel?.ignoresMouseEvents = true
        panel?.acceptsKeyInput = false
        previousApp = nil
        previousWindowID = nil
        tabMarker = ""
        ttyPath = ""
        responsePipe = ""
        activeSessionID = ""

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

            try? await Task.sleep(nanoseconds: AppConfig.hideDelayNanos)
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.hideTask = nil
                self.isTransitioningOut = false

                if !self.viewModel.expanded, let panel = self.panel {
                    self.isPresented = false
                    self.topmostSpaceManager.detach(window: panel)
                    panel.orderOut(nil)
                    self.stopTrackingLoop()
                    self.viewModel.contentVisible = true
                }

                self.activeSessionID = ""

                self.presentNextQueuedCommandIfNeeded()
            }
        }
    }

    // MARK: - System Layout

    @objc private func handleSystemLayoutChange(_: Notification) {
        refreshGeometry(force: true)
    }

    private func ensurePanel() {
        guard panel == nil else { return }

        let view = ZStack(alignment: .top) {
            IslandView(model: viewModel) { [weak self] in
                self?.dismiss()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.clear)

        let hostingView = NSHostingView(rootView: view)
        let panel = OverlayPanel(
            contentRect: viewModel.geometry.screenFrame,
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

        if !force, isGeometryRefreshSuspended {
            updatePanelInteractivity()
            return
        }

        let latestGeometry = NotchGeometry.detect()
        if hasMeaningfulGeometryChange(from: viewModel.geometry, to: latestGeometry) {
            viewModel.geometry = latestGeometry
        }

        if !isPresented {
            if force {
                let targetFrame = latestGeometry.screenFrame
                if shouldUpdatePanelFrame(current: panel.frame, target: targetFrame) {
                    panel.setFrame(targetFrame, display: false)
                }
            }
            return
        }

        let targetFrame = latestGeometry.screenFrame
        if shouldUpdatePanelFrame(current: panel.frame, target: targetFrame) {
            panel.setFrame(targetFrame, display: true)
        }
        updatePanelInteractivity()
        if panel.level != AppConfig.panelWindowLevel {
            panel.level = AppConfig.panelWindowLevel
        }

        if force {
            panel.orderFrontRegardless()
            topmostSpaceManager.attach(window: panel)
        }
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
        isTransitioningOut = false
        activeSessionID = ""
    }
}
