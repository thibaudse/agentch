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
            self?.eventServer?.resolveQuestion(sessionId: sessionId, answer: answer)
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
                        if event.event == .elicitation {
                            self.sessionManager.setQuestion(
                                sessionId: event.sessionId,
                                question: event.question ?? "Claude is asking a question",
                                options: event.questionOptions ?? []
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

    private func observeFullScreen() {
        // Load MediaRemote via dlopen
        guard let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY) else {
            NSLog("[agentch] MediaRemote dlopen failed"); return
        }
        guard let pIsPlaying = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying"),
              let pGetPID = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationPID") else {
            NSLog("[agentch] MediaRemote symbols not found"); return
        }
        NSLog("[agentch] Full-screen player detection active")

        typealias IsPlayingFn = @convention(c) (DispatchQueue, @escaping @Sendable (Bool) -> Void) -> Void
        typealias NowPlayingPIDFn = @convention(c) (DispatchQueue, @escaping @Sendable (Int32) -> Void) -> Void

        let getIsPlaying = unsafeBitCast(pIsPlaying, to: IsPlayingFn.self)
        let getPID = unsafeBitCast(pGetPID, to: NowPlayingPIDFn.self)

        // Check every 2 seconds on a background thread to avoid blocking main
        let checkFullScreen = { [weak self] in
            nonisolated(unsafe) var playing = false
            nonisolated(unsafe) var playerPID: Int32 = 0

            let semaphore = DispatchSemaphore(value: 0)
            getIsPlaying(DispatchQueue.global()) { isPlaying in
                playing = isPlaying
                semaphore.signal()
            }
            semaphore.wait()

            guard playing else { return false }

            let sem2 = DispatchSemaphore(value: 0)
            getPID(DispatchQueue.global()) { pid in
                playerPID = pid
                sem2.signal()
            }
            sem2.wait()

            guard playerPID > 0 else { return false }
            return self?.isPlayerFullScreen(pid: playerPID) ?? false
        }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            while self != nil {
                Thread.sleep(forTimeInterval: 2)
                let shouldHide = checkFullScreen()
                Task { @MainActor [weak self] in
                    guard let panel = self?.panel else { return }
                    if shouldHide && panel.isVisible {
                        panel.orderOut(nil)
                    } else if !shouldHide && !panel.isVisible {
                        panel.orderFrontRegardless()
                    }
                }
            }
        }
    }

    private nonisolated func isPlayerFullScreen(pid: Int32) -> Bool {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return false }
        let screenFrame = NSScreen.main?.frame ?? .zero

        for window in windowList {
            guard let wPid = window[kCGWindowOwnerPID as String] as? Int32,
                  wPid == pid,
                  let bounds = window[kCGWindowBounds as String] as? [String: Any] else { continue }
            let w = (bounds["Width"] as? Int).map(CGFloat.init) ?? (bounds["Width"] as? CGFloat) ?? 0
            let h = (bounds["Height"] as? Int).map(CGFloat.init) ?? (bounds["Height"] as? CGFloat) ?? 0
            // Full-screen windows cover the entire screen including menu bar
            // Allow small tolerance for the menu bar (< 50px difference)
            if w >= screenFrame.width && h >= screenFrame.height - 50 {
                return true
            }
        }
        return false
    }

    private func autoInstallHooksIfNeeded() {
        HookManager.installAll(port: UInt16(httpPort))
    }
}
