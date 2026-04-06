import SwiftUI

extension Notification.Name {
    static let agentChHooksToggled = Notification.Name("agentChHooksToggled")
}

@main
struct agentchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("agentch", image: "MenuBarIcon") {
            MenuBarView(sessionManager: appDelegate.sessionManager)
        }
        .menuBarExtraStyle(.menu)
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let sessionManager = SessionManager()
    let screenManager = ScreenManager()
    let pillPosition = PillPosition()
    private var panel: AgentChPanel?
    private var eventServer: EventServer?
    @AppStorage("httpPort") var httpPort: Int = 27182
    @AppStorage("hooksDisabled") var hooksDisabled: Bool = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupPanel()
        startServer()
        autoInstallHooksIfNeeded()
        observeHooksToggle()
        observeScreenChange()
        observeFullScreen()
        sessionManager.startCleanup()
        SettingsWindowController.shared.pillPosition = pillPosition
        SettingsWindowController.shared.screenManager = screenManager
        sessionManager.onResolvePermission = { [weak self] sessionId, allow in
            self?.eventServer?.resolveDecision(sessionId: sessionId, allow: allow)
        }
        sessionManager.onResolveQuestion = { [weak self] sessionId, answer in
            // Check if this was an AskUserQuestion (PermissionRequest) or a real Elicitation
            if let session = self?.sessionManager.sessions.first(where: { $0.id == sessionId }),
               session.isAskUserQuestion {
                // AskUserQuestion is a PermissionRequest — allow it
                self?.eventServer?.resolveDecision(sessionId: sessionId, allow: answer != nil)
            } else {
                self?.eventServer?.resolveQuestion(sessionId: sessionId, answer: answer)
            }
        }
        eventServer?.onDecisionExpired = { [weak self] sessionId in
            Task { @MainActor in
                guard let self,
                      let index = self.sessionManager.sessions.firstIndex(where: { $0.id == sessionId }) else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    self.sessionManager.sessions[index].pendingPermission = nil
                    self.sessionManager.sessions[index].pendingQuestion = nil
                }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        eventServer?.stop()
        pillPosition.stopMonitoring()
    }

    private func setupPanel() {
        let panel = AgentChPanel()
        pillPosition.screen = screenManager.selectedScreen
        panel.coverScreen(screenManager.selectedScreen)

        let pillView = PillGroupView(sessionManager: sessionManager, pillPosition: pillPosition)
        let hostingView = PillHostingView(rootView: pillView)
        hostingView.frame = NSRect(origin: .zero, size: panel.frame.size)
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView

        panel.orderFrontRegardless()
        self.panel = panel

        pillPosition.startMonitoring()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.panel?.coverScreen(self?.screenManager.selectedScreen)
            }
        }
    }

    private func startServer() {
        guard eventServer == nil else { return }
        do {
            let server = try EventServer(
                port: UInt16(httpPort),
                onEvent: { [weak self] event in
                    NSLog("[agentch] onEvent: %@ session=%@", event.event.rawValue, event.sessionId)
                    Task { @MainActor in
                        guard let self else { return }
                        self.sessionManager.handleEvent(event)
                    }
                },
                onDecisionEvent: { [weak self] event in
                    NSLog("[agentch] onDecisionEvent: %@ session=%@", event.event.rawValue, event.sessionId)
                    Task { @MainActor in
                        guard let self else { return }
                        self.sessionManager.handleEvent(event)
                        if event.event == .elicitation || event.toolName == "AskUserQuestion" {
                            self.sessionManager.setQuestion(
                                sessionId: event.sessionId,
                                question: event.question ?? "Claude is asking a question",
                                options: event.questionOptions ?? [],
                                isAskUserQuestion: event.toolName == "AskUserQuestion"
                            )
                        } else {
                            self.sessionManager.setPermission(
                                sessionId: event.sessionId,
                                toolName: event.toolName ?? "Permission",
                                toolInput: event.toolInput,
                                filePath: event.toolFilePath
                            )
                        }
                    }
                }
            )
            server.start()
            self.eventServer = server
        } catch {
            NSLog("[agentch] Failed to start server: %@", error.localizedDescription)
        }
    }

    private func observeHooksToggle() {
        NotificationCenter.default.addObserver(
            forName: .agentChHooksToggled,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.hooksDisabled {
                    self.eventServer?.stop()
                    self.eventServer = nil
                } else {
                    self.startServer()
                }
            }
        }
    }

    private func observeScreenChange() {
        NotificationCenter.default.addObserver(
            forName: .agentChScreenChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let selectedScreen = self.screenManager.selectedScreen
                self.panel?.coverScreen(selectedScreen)
                self.pillPosition.screen = selectedScreen
                self.pillPosition.resetToDefault()
            }
        }
    }

    private static let playerBundleIDs: Set<String> = [
        // Browsers
        "com.apple.Safari", "com.google.Chrome", "org.mozilla.firefox",
        "company.thebrowser.Browser", "com.microsoft.edgemac",
        "com.brave.Browser", "com.operasoftware.Opera",
        // Media players
        "com.apple.QuickTimePlayerX", "com.apple.TV", "org.videolan.vlc",
        "com.colliderli.iina", "io.mpv", "tv.plex.player",
    ]

    private func observeFullScreen() {
        let check = { [weak self] in
            self?.updateFullScreenVisibility()
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main) { _ in check() }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil, queue: .main) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { check() }
            }
    }

    private func updateFullScreenVisibility() {
        guard let panel else { return }
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleID = frontApp.bundleIdentifier,
              Self.playerBundleIDs.contains(bundleID) else {
            if !panel.isVisible { panel.orderFrontRegardless() }
            return
        }

        let screenFrame = NSScreen.main?.frame ?? .zero
        var isFullScreen = false
        if let wl = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] {
            for w in wl {
                guard let wPid = w[kCGWindowOwnerPID as String] as? Int32,
                      wPid == frontApp.processIdentifier,
                      let b = w[kCGWindowBounds as String] as? [String: Any] else { continue }
                let width = CGFloat((b["Width"] as? Int) ?? 0)
                let height = CGFloat((b["Height"] as? Int) ?? 0)
                if width >= screenFrame.width && height >= screenFrame.height - 50 {
                    isFullScreen = true
                    break
                }
            }
        }

        if isFullScreen && panel.isVisible {
            panel.orderOut(nil)
        } else if !isFullScreen && !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    private func autoInstallHooksIfNeeded() {
        HookManager.installAll(port: UInt16(httpPort))
    }
}
