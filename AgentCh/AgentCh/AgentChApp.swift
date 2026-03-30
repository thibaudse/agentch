import SwiftUI

extension Notification.Name {
    static let agentChHooksToggled = Notification.Name("agentChHooksToggled")
}

@main
struct AgentChApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("AgentCh", systemImage: "bubble.left.and.bubble.right.fill") {
            MenuBarView(sessionManager: appDelegate.sessionManager, screenManager: appDelegate.screenManager)
        }
        .menuBarExtraStyle(.menu)
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let sessionManager = SessionManager()
    let screenManager = ScreenManager()
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
    }

    func applicationWillTerminate(_ notification: Notification) {
        eventServer?.stop()
    }

    private func setupPanel() {
        let panel = AgentChPanel()
        let pillView = PillGroupView(sessionManager: sessionManager, screenManager: screenManager)
        let hostingView = PillHostingView(rootView: pillView)
        hostingView.frame = panel.frame
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
        panel.coverScreen(screenManager.selectedScreen)
        panel.orderFrontRegardless()
        self.panel = panel

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
        guard !hooksDisabled else { return }
        do {
            let server = try EventServer(port: UInt16(httpPort)) { [weak self] event in
                Task { @MainActor in
                    self?.sessionManager.handleEvent(event)
                }
            }
            server.start()
            self.eventServer = server
        } catch {
            print("Failed to start event server: \(error)")
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
                self.panel?.coverScreen(self.screenManager.selectedScreen)
            }
        }
    }

    private func autoInstallHooksIfNeeded() {
        let port = UInt16(httpPort)
        if !HookManager.checkInstalled(port: port) {
            try? HookManager.install(port: port)
        }
    }
}
