import SwiftUI

extension Notification.Name {
    static let agentChHooksToggled = Notification.Name("agentChHooksToggled")
}

@main
struct agentchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Handle CLI flags before launching the app
        let args = CommandLine.arguments
        if args.contains("--launchd") {
            LaunchdHelper.install()
            exit(0)
        }
        if args.contains("--unlaunchd") {
            LaunchdHelper.uninstall()
            exit(0)
        }
    }

    var body: some Scene {
        MenuBarExtra("agentch", systemImage: "bubble.left.and.bubble.right.fill") {
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
        requestAccessibilityIfNeeded()
        setupPanel()
        startServer()
        autoInstallHooksIfNeeded()
        observeHooksToggle()
        observeScreenChange()
        sessionManager.startCleanup()
        SettingsWindowController.shared.pillPosition = pillPosition
        SettingsWindowController.shared.screenManager = screenManager
        sessionManager.onResolvePermission = { [weak self] sessionId, allow in
            self?.eventServer?.resolveDecision(sessionId: sessionId, allow: allow)
        }
        eventServer?.onDecisionExpired = { [weak self] sessionId in
            Task { @MainActor in
                guard let self,
                      let index = self.sessionManager.sessions.firstIndex(where: { $0.id == sessionId }),
                      self.sessionManager.sessions[index].pendingPermission != nil else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    self.sessionManager.sessions[index].pendingPermission = nil
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
                        self.sessionManager.setPermission(
                            sessionId: event.sessionId,
                            toolName: event.toolName ?? "Permission",
                            toolInput: event.toolInput
                        )
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

    private nonisolated func requestAccessibilityIfNeeded() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
    }

    private func autoInstallHooksIfNeeded() {
        HookManager.installAll(port: UInt16(httpPort))
    }
}
