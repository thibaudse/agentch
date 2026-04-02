import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var pillPosition: PillPosition
    @ObservedObject var screenManager: ScreenManager
    @AppStorage("httpPort") var httpPort: Int = 27182
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("pillScale") var pillScale: Double = 1.0
    @AppStorage("peekDuration") var peekDuration: Double = 2.5
    @AppStorage("notificationSound") var selectedSound: String = "Blow"
    @AppStorage("hooksDisabled") var hooksDisabled: Bool = false
    @State private var hookRefreshToken = UUID()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                generalSection
                appearanceSection
                soundSection
                positionSection
                hooksSection

                Text("AgentCh v1.0")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .padding(20)
        }
        .frame(width: 450, height: 580)
    }

    // MARK: - General

    @ViewBuilder
    private var generalSection: some View {
        SettingsSection(icon: "gearshape", title: "General") {
            SettingsRow("Launch at Login") {
                Toggle("", isOn: $launchAtLogin)
                    .labelsHidden()
                    .onChange(of: launchAtLogin) { _, newValue in
                        updateLaunchAtLogin(newValue)
                    }
            }
            SettingsRow("HTTP Port") {
                TextField("", value: $httpPort, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
            }
            Text("Requires restart")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    // MARK: - Appearance

    @ViewBuilder
    private var appearanceSection: some View {
        SettingsSection(icon: "paintbrush", title: "Appearance") {
            SettingsRow("Pill Size") {
                HStack(spacing: 12) {
                    Slider(value: $pillScale, in: 0.5...2.0, step: 0.1)
                        .frame(width: 120)
                    Text(String(format: "%.1fx", pillScale))
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 36, alignment: .trailing)
                }
            }
            // Mini pill preview
            HStack(spacing: 6) {
                StatusDot(status: .thinking)
                MascotView(agentType: .claude, status: .thinking, size: 16)
            }
            .scaleEffect(pillScale)
            .frame(height: 30)
            .frame(maxWidth: .infinity)

            Divider()

            SettingsRow("Collapse Duration") {
                HStack(spacing: 12) {
                    Slider(value: $peekDuration, in: 1...10, step: 0.5)
                        .frame(width: 120)
                    Text(String(format: "%.1fs", peekDuration))
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 36, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - Sound

    @ViewBuilder
    private var soundSection: some View {
        SettingsSection(icon: "speaker.wave.2", title: "Sound") {
            SettingsRow("Notification Sound") {
                Picker("", selection: $selectedSound) {
                    ForEach(SoundPlayer.availableSounds, id: \.self) { sound in
                        Text(sound).tag(sound)
                    }
                }
                .labelsHidden()
                .frame(width: 140)
                .onChange(of: selectedSound) { _, newValue in
                    SoundPlayer.preview(newValue)
                }
            }
        }
    }

    // MARK: - Position

    private var currentPositionIndex: Int? {
        var bestIndex: Int?
        var bestDist: CGFloat = .greatestFiniteMagnitude
        for (i, pos) in PillScreenPosition.all.enumerated() {
            let target = pillPosition.offsetFor(pos)
            let dx = pillPosition.offset.width - target.width
            let dy = pillPosition.offset.height - target.height
            let dist = sqrt(dx * dx + dy * dy)
            if dist < bestDist {
                bestDist = dist
                bestIndex = i
            }
        }
        return bestDist < 50 ? bestIndex : nil
    }

    @ViewBuilder
    private var positionSection: some View {
        SettingsSection(icon: "rectangle.inset.filled", title: "Position") {
            positionGrid
                .frame(maxWidth: .infinity)

            Divider()

            SettingsRow("Display") {
                Picker("", selection: $screenManager.selectedScreenIndex) {
                    ForEach(screenManager.screenNames, id: \.index) { screen in
                        Text(screen.name).tag(screen.index)
                    }
                }
                .labelsHidden()
                .frame(width: 180)
            }
        }
    }

    @ViewBuilder
    private var positionGrid: some View {
        let columns = [
            GridItem(.fixed(44), spacing: 6),
            GridItem(.fixed(44), spacing: 6),
            GridItem(.fixed(44), spacing: 6),
        ]

        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(PillScreenPosition.all.enumerated()), id: \.offset) { index, pos in
                let isActive = currentPositionIndex == index
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        pillPosition.moveTo(pos)
                    }
                } label: {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isActive ? Color.accentColor : Color.primary.opacity(0.08))
                        .frame(width: 44, height: 32)
                        .overlay {
                            if isActive {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 6, height: 6)
                            }
                        }
                }
                .buttonStyle(.plain)
                .help(pos.label)
            }
        }
    }

    // MARK: - Hooks

    @ViewBuilder
    private var hooksSection: some View {
        SettingsSection(icon: "link", title: "Hooks") {
            SettingsRow("Enable Hooks") {
                Toggle("", isOn: Binding(
                    get: { !hooksDisabled },
                    set: { enabled in
                        hooksDisabled = !enabled
                        NotificationCenter.default.post(name: .agentChHooksToggled, object: nil)
                    }
                ))
                .labelsHidden()
            }

            if !hooksDisabled {
                Divider()

                ForEach(AgentHookConfig.all, id: \.label) { agent in
                    let installed = HookManager.checkInstalled(port: UInt16(httpPort), agent: agent)
                    SettingsRow(agent.label) {
                        HStack(spacing: 8) {
                            Text(installed ? "Installed" : "Not Installed")
                                .font(.caption)
                                .foregroundStyle(installed ? .green : .secondary)
                            Toggle("", isOn: Binding(
                                get: { installed },
                                set: { newValue in
                                    if newValue {
                                        try? HookManager.install(port: UInt16(httpPort), agent: agent)
                                    } else {
                                        try? HookManager.uninstall(agent: agent)
                                    }
                                    hookRefreshToken = UUID()
                                }
                            ))
                            .labelsHidden()
                        }
                    }
                }
                .id(hookRefreshToken)

                Divider()

                HStack {
                    Spacer()
                    Button("Install All") {
                        HookManager.installAll(port: UInt16(httpPort))
                        hookRefreshToken = UUID()
                    }
                    Button("Uninstall All") {
                        HookManager.uninstallAll()
                        hookRefreshToken = UUID()
                    }
                }
                .font(.caption)
            }
        }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = !enabled
        }
    }
}

// MARK: - Reusable components

struct SettingsSection<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.primary.opacity(0.04))
        )
    }
}

struct SettingsRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    init(_ label: String, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.content = content
    }

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            content()
        }
    }
}

@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?
    var pillPosition: PillPosition?
    var screenManager: ScreenManager?

    func showWindow() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        guard let pillPosition, let screenManager else { return }

        let settingsView = SettingsView(pillPosition: pillPosition, screenManager: screenManager)
        let hostingView = NSHostingView(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 580),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = "AgentCh Settings"
        window.contentView = hostingView
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }
}
