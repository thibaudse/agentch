import AppKit
import SwiftUI

// MARK: - Configuration

let socketPath = "/tmp/agent-island.sock"
let defaultDisplayDuration: TimeInterval = 0 // 0 = stay until dismiss

// MARK: - Notch Geometry

struct NotchInfo {
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    let notchMinX: CGFloat  // left edge of notch in screen coords
    let screenFrame: NSRect
    let hasNotch: Bool

    static func detect() -> NotchInfo {
        guard let screen = NSScreen.main else {
            return NotchInfo(notchWidth: 185, notchHeight: 32, notchMinX: 0, screenFrame: .zero, hasNotch: false)
        }
        let frame = screen.frame
        let safeTop = screen.safeAreaInsets.top

        if safeTop > 0,
           let topLeft = screen.auxiliaryTopLeftArea,
           let topRight = screen.auxiliaryTopRightArea {
            // Notch sits between the right edge of topLeft and left edge of topRight
            let notchMinX = topLeft.maxX
            let notchMaxX = topRight.minX
            let notchWidth = notchMaxX - notchMinX
            return NotchInfo(
                notchWidth: notchWidth,
                notchHeight: safeTop,
                notchMinX: notchMinX,
                screenFrame: frame,
                hasNotch: true
            )
        }
        // No notch — fallback to a centered pill
        return NotchInfo(
            notchWidth: 185,
            notchHeight: 32,
            notchMinX: frame.midX - 92.5,
            screenFrame: frame,
            hasNotch: false
        )
    }
}

// MARK: - Island State (observable so SwiftUI close button can dismiss)

class IslandState: ObservableObject {
    @Published var message: String = ""
    @Published var agentName: String = ""
    @Published var isVisible: Bool = false
    /// Drives the spring expansion animation inside SwiftUI
    @Published var expanded: Bool = false

    // Weak reference to controller for close button action
    weak var controller: IslandWindowController?

    func requestDismiss() {
        controller?.dismiss()
    }
}

// MARK: - Notch Shape

/// A rounded-rect shape with the top corners matching the notch radius
/// and the bottom corners with a larger expansion radius.
struct NotchShape: Shape {
    let topRadius: CGFloat
    let bottomRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let tr = topRadius
        let br = bottomRadius

        // Start at top-left, after the top-left corner radius
        p.move(to: CGPoint(x: rect.minX + tr, y: rect.minY))

        // Top edge
        p.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))

        // Top-right corner
        p.addArc(
            center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr),
            radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false
        )

        // Right edge
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))

        // Bottom-right corner
        p.addArc(
            center: CGPoint(x: rect.maxX - br, y: rect.maxY - br),
            radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false
        )

        // Bottom edge
        p.addLine(to: CGPoint(x: rect.minX + br, y: rect.maxY))

        // Bottom-left corner
        p.addArc(
            center: CGPoint(x: rect.minX + br, y: rect.maxY - br),
            radius: br, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false
        )

        // Left edge
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tr))

        // Top-left corner
        p.addArc(
            center: CGPoint(x: rect.minX + tr, y: rect.minY + tr),
            radius: tr, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false
        )

        p.closeSubpath()
        return p
    }
}

// MARK: - Island Content View

struct IslandContentView: View {
    @ObservedObject var state: IslandState
    let notch: NotchInfo

    let expandedExtraHeight: CGFloat = 40

    private var expandedWidth: CGFloat { max(notch.notchWidth + 120, 340) }
    private var expandedHeight: CGFloat { notch.notchHeight + expandedExtraHeight }

    // Scale factors: collapsed notch size relative to expanded size
    private var collapsedScaleX: CGFloat { notch.notchWidth / expandedWidth }
    private var collapsedScaleY: CGFloat { notch.notchHeight / expandedHeight }

    var body: some View {
        // Single composition: shape + content clipped together, scaled as one unit
        ZStack(alignment: .bottom) {
            Color.black

            HStack(spacing: 10) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .shadow(color: .green.opacity(0.7), radius: 5)

                if !state.agentName.isEmpty {
                    Text(state.agentName)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }

                Text(state.message)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Button(action: { state.requestDismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
        .frame(width: expandedWidth, height: expandedHeight)
        .clipShape(NotchShape(topRadius: notch.hasNotch ? 8 : 12, bottomRadius: 18))
        .scaleEffect(
            x: state.expanded ? 1 : collapsedScaleX,
            y: state.expanded ? 1 : collapsedScaleY,
            anchor: .top
        )
    }
}

// MARK: - Island Window Controller

class IslandWindowController {
    private var window: NSWindow?
    private var dismissTimer: Timer?
    private let state = IslandState()
    private let notch = NotchInfo.detect()

    // Pre-computed window frame at expanded size (the SwiftUI view handles the visual sizing)
    private var maxWindowFrame: NSRect {
        let expandedExtraHeight: CGFloat = 40
        let totalHeight = notch.notchHeight + expandedExtraHeight
        let expandedWidth = max(notch.notchWidth + 120, 340)
        let notchCenterX = notch.notchMinX + notch.notchWidth / 2
        let x = notchCenterX - expandedWidth / 2
        let y = notch.screenFrame.maxY - totalHeight
        return NSRect(x: x, y: y, width: expandedWidth, height: totalHeight)
    }

    init() {
        state.controller = self
    }

    private func ensureWindow() {
        guard window == nil else { return }

        let view = IslandContentView(state: state, notch: notch)
        let hosting = NSHostingView(rootView: view)

        let w = NSWindow(
            contentRect: maxWindowFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        w.level = NSWindow.Level(Int(CGShieldingWindowLevel()))
        w.backgroundColor = .clear
        w.isOpaque = false
        w.hasShadow = false
        w.ignoresMouseEvents = false
        w.collectionBehavior = [.fullScreenAuxiliary]
        w.contentView = hosting
        w.alphaValue = 1.0
        self.window = w
    }

    func show(message: String, agent: String = "", duration: TimeInterval = defaultDisplayDuration) {
        DispatchQueue.main.async { [self] in
            self.dismissTimer?.invalidate()

            // Update content
            state.message = message
            state.agentName = agent
            state.isVisible = true

            ensureWindow()
            guard let window = self.window else { return }

            // Reset to collapsed state, make visible
            state.expanded = false
            window.setFrame(maxWindowFrame, display: true)
            window.alphaValue = 1.0
            window.ignoresMouseEvents = false
            window.orderFrontRegardless()

            // Trigger the bouncy spring expansion on the next run-loop tick
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                withAnimation(.bouncy(duration: 0.35)) {
                    self.state.expanded = true
                }
            }

            if duration > 0 {
                self.dismissTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                    self?.dismiss()
                }
            }
        }
    }

    func dismiss() {
        DispatchQueue.main.async { [self] in
            self.dismissTimer?.invalidate()
            state.isVisible = false

            // Same duration, no bounce
            withAnimation(.smooth(duration: 0.35)) {
                state.expanded = false
            }

            // Once the animation settles, hide the window
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                guard let window = self.window, !self.state.expanded else { return }
                window.orderOut(nil)
            }
        }
    }
}

// MARK: - Socket Server

class SocketServer {
    let path: String
    let island: IslandWindowController
    private var serverSocket: Int32 = -1

    init(path: String, island: IslandWindowController) {
        self.path = path
        self.island = island
    }

    func start() {
        unlink(path)

        serverSocket = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            NSLog("AgentIsland: Failed to create socket")
            return
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = path.utf8CString
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            let bound = ptr.withMemoryRebound(to: CChar.self, capacity: 104) { dest in
                pathBytes.withUnsafeBufferPointer { src in
                    let count = min(src.count, 104)
                    dest.update(from: src.baseAddress!, count: count)
                    return count
                }
            }
            _ = bound
        }

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                bind(serverSocket, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0 else {
            NSLog("AgentIsland: Failed to bind socket: \(String(cString: strerror(errno)))")
            return
        }

        guard listen(serverSocket, 5) == 0 else {
            NSLog("AgentIsland: Failed to listen on socket")
            return
        }

        NSLog("AgentIsland: Listening on \(path)")

        DispatchQueue.global(qos: .utility).async { [self] in
            while true {
                let clientSocket = accept(self.serverSocket, nil, nil)
                guard clientSocket >= 0 else { continue }
                DispatchQueue.global(qos: .utility).async {
                    self.handleClient(clientSocket)
                }
            }
        }
    }

    private func handleClient(_ clientSocket: Int32) {
        defer { close(clientSocket) }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)

        while true {
            let bytesRead = read(clientSocket, &buffer, buffer.count)
            if bytesRead <= 0 { break }
            data.append(contentsOf: buffer[0..<bytesRead])
            if buffer[0..<bytesRead].contains(0x0A) { break }
        }

        guard !data.isEmpty else { return }
        if data.last == 0x0A { data.removeLast() }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            NSLog("AgentIsland: Invalid JSON received")
            return
        }

        let action = json["action"] as? String ?? "show"

        switch action {
        case "show":
            let message = json["message"] as? String ?? "Hello World"
            let agent = json["agent"] as? String ?? ""
            let duration = json["duration"] as? TimeInterval ?? defaultDisplayDuration
            island.show(message: message, agent: agent, duration: duration)
        case "dismiss":
            island.dismiss()
        case "quit":
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
        default:
            NSLog("AgentIsland: Unknown action: \(action)")
        }

        let response = "OK\n"
        _ = response.withCString { ptr in
            write(clientSocket, ptr, 3)
        }
    }

    func stop() {
        if serverSocket >= 0 { close(serverSocket) }
        unlink(path)
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    let island = IslandWindowController()
    var server: SocketServer!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        server = SocketServer(path: socketPath, island: island)
        server.start()

        signal(SIGTERM, SIG_IGN)
        signal(SIGINT, SIG_IGN)

        let signalSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        signalSource.setEventHandler {
            self.server.stop()
            NSApp.terminate(nil)
        }
        signalSource.resume()

        let intSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        intSource.setEventHandler {
            self.server.stop()
            NSApp.terminate(nil)
        }
        intSource.resume()

        NSLog("AgentIsland: Ready")
    }

    func applicationWillTerminate(_ notification: Notification) {
        server?.stop()
    }
}

// MARK: - Main

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
