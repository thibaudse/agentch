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
    @AppStorage("soundEnabled") var soundEnabled: Bool = true
    @AppStorage("snapToGrid") var snapToGrid: Bool = true
    @AppStorage("hooksDisabled") var hooksDisabled: Bool = false
    @State private var hookRefreshToken = UUID()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    // Hero header with close button
                    ZStack(alignment: .topLeading) {
                        heroHeader
                        closeButton
                    }
                    .padding(.bottom, 24)

                    Group {
                        sectionHeader("General", icon: "gearshape.fill", color: .gray)
                        generalSection
                            .padding(.bottom, 20)

                        sectionHeader("Appearance", icon: "paintbrush.fill", color: .purple)
                        appearanceSection
                            .padding(.bottom, 20)

                        sectionHeader("Sound", icon: "speaker.wave.2.fill", color: .pink)
                        soundSection
                            .padding(.bottom, 20)

                        sectionHeader("Position", icon: "rectangle.inset.filled", color: .blue)
                        positionSection
                            .padding(.bottom, 20)

                        sectionHeader("Hooks", icon: "link", color: .orange)
                        hooksSection
                    }

                    Text("v1.0")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.15))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 28)
                        .padding(.bottom, 16)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
            }
        }
        .frame(width: 520, height: 680)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
        }
        .padding(50)
    }

    // MARK: - Hero Header

    @ViewBuilder
    private var heroHeader: some View {
        VStack(spacing: 8) {
            ClawdMascot(status: .idle, animationPhase: 0)
                .frame(width: 40, height: 40)

            Text("AgentCh")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text("Visual feedback for your AI agents")
                .font(.system(size: 11))
                .foregroundStyle(.primary.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    // MARK: - Close Button

    @ViewBuilder
    private var closeButton: some View {
        Button {
            NSApp.keyWindow?.close()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(.primary.opacity(0.08))
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 18, height: 18)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(color.opacity(0.15))
                )
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.4))
                .tracking(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 10)
    }

    // MARK: - General

    @ViewBuilder
    private var generalSection: some View {
        VStack(spacing: 2) {
            SettingsCard {
                HStack {
                    Text("Launch at Login")
                        .font(.system(size: 13))
                    Spacer()
                    Toggle("", isOn: $launchAtLogin)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .onChange(of: launchAtLogin) { _, newValue in
                            updateLaunchAtLogin(newValue)
                        }
                }
            }
            SettingsCard {
                HStack {
                    Text("HTTP Port")
                        .font(.system(size: 13))
                    Spacer()
                    HStack(spacing: 6) {
                        TextField("", value: $httpPort, format: .number)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, design: .monospaced))
                            .frame(width: 56)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(.primary.opacity(0.06))
                            )
                        Text("restart needed")
                            .font(.system(size: 10))
                            .foregroundStyle(.primary.opacity(0.2))
                    }
                }
            }
        }
    }

    // MARK: - Appearance

    @ViewBuilder
    private var appearanceSection: some View {
        VStack(spacing: 2) {
            SettingsCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Pill Size")
                            .font(.system(size: 13))
                        Spacer()
                        Text(String(format: "%.0f%%", pillScale * 100))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.purple)
                    }
                    Slider(value: $pillScale, in: 0.5...2.0, step: 0.1)
                        .tint(.purple)
                    // Mini pill preview
                    HStack {
                        Spacer()
                        HStack(spacing: 6 * CGFloat(pillScale)) {
                            StatusDot(status: .idle, scale: CGFloat(pillScale))
                            MascotView(agentType: .claude, status: .idle, size: 16 * CGFloat(pillScale))
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(
                            Capsule()
                                .fill(.primary.opacity(0.04))
                                .overlay(
                                    Capsule()
                                        .stroke(.primary.opacity(0.06), lineWidth: 1)
                                )
                        )
                        Spacer()
                    }
                }
            }
            SettingsCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Auto-Collapse")
                            .font(.system(size: 13))
                        Spacer()
                        Text(String(format: "%.1fs", peekDuration))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.purple)
                    }
                    Slider(value: $peekDuration, in: 1...10, step: 0.5)
                        .tint(.purple)
                }
            }
        }
    }

    // MARK: - Sound

    @ViewBuilder
    private var soundSection: some View {
        VStack(spacing: 2) {
            SettingsCard {
                HStack {
                    Text("Notification Sound")
                        .font(.system(size: 13))
                    Spacer()
                    Toggle("", isOn: $soundEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }
            if soundEnabled {
                SettingsCard {
                    HStack {
                        Text("Sound")
                            .font(.system(size: 13))
                        Spacer()
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
        VStack(spacing: 2) {
            SettingsCard {
                HStack(alignment: .top) {
                    Text("Screen Position")
                        .font(.system(size: 13))
                    Spacer()
                    positionGrid
                }
            }
            SettingsCard {
                HStack {
                    Text("Snap to Grid")
                        .font(.system(size: 13))
                    Spacer()
                    Toggle("", isOn: $snapToGrid)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .onChange(of: snapToGrid) { _, enabled in
                            if enabled {
                                pillPosition.snapToNearest()
                            }
                        }
                }
            }
            SettingsCard {
                HStack {
                    Text("Display")
                        .font(.system(size: 13))
                    Spacer()
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
    }

    @ViewBuilder
    private var positionGrid: some View {
        // Mini screen representation
        VStack(spacing: 0) {
            let columns = [
                GridItem(.fixed(32), spacing: 2),
                GridItem(.fixed(32), spacing: 2),
                GridItem(.fixed(32), spacing: 2),
            ]

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(PillScreenPosition.all.enumerated()), id: \.offset) { index, pos in
                    let isActive = currentPositionIndex == index
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            pillPosition.moveTo(pos)
                        }
                    } label: {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(isActive ? Color.blue : .primary.opacity(0.05))
                            .frame(width: 32, height: 22)
                            .overlay {
                                if isActive {
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 4, height: 4)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .help(pos.label)
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.primary.opacity(0.1), lineWidth: 1)
            )

            // Mini stand
            RoundedRectangle(cornerRadius: 1)
                .fill(.primary.opacity(0.1))
                .frame(width: 20, height: 4)
                .padding(.top, 2)
        }
    }

    // MARK: - Hooks

    @ViewBuilder
    private var hooksSection: some View {
        VStack(spacing: 2) {
            SettingsCard {
                HStack {
                    Text("Enable Hooks")
                        .font(.system(size: 13))
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { !hooksDisabled },
                        set: { enabled in
                            hooksDisabled = !enabled
                            NotificationCenter.default.post(name: .agentChHooksToggled, object: nil)
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }
            }

            if !hooksDisabled {
                ForEach(AgentHookConfig.all, id: \.label) { agent in
                    let installed = HookManager.checkInstalled(port: UInt16(httpPort), agent: agent)
                    SettingsCard {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(agent.label)
                                    .font(.system(size: 13, weight: .medium))
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(installed ? Color.green : .primary.opacity(0.15))
                                        .frame(width: 6, height: 6)
                                    Text(installed ? "Installed" : "Not Installed")
                                        .font(.system(size: 11))
                                        .foregroundStyle(installed ? .green : .secondary)
                                }
                            }
                            Spacer()
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
                            .toggleStyle(.switch)
                            .controlSize(.small)
                        }
                    }
                }
                .id(hookRefreshToken)

                HStack(spacing: 8) {
                    Spacer()
                    Button("Install All") {
                        HookManager.installAll(port: UInt16(httpPort))
                        hookRefreshToken = UUID()
                    }
                    .buttonStyle(SmallPillButton())
                    Button("Uninstall All") {
                        HookManager.uninstallAll()
                        hookRefreshToken = UUID()
                    }
                    .buttonStyle(SmallPillButton())
                }
                .padding(.top, 6)
            }
        }
    }

    // MARK: - Helpers

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

// MARK: - Card Component

struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @State private var isHovered = false

    var body: some View {
        content()
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.primary.opacity(isHovered ? 0.07 : 0.04))
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
    }
}

// MARK: - Small Pill Button

struct SmallPillButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.primary.opacity(0.6))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(.primary.opacity(configuration.isPressed ? 0.1 : 0.06))
            )
            .overlay(
                Capsule()
                    .stroke(.primary.opacity(0.08), lineWidth: 1)
            )
    }
}

/// Borderless window that can become key (for text fields, pickers, etc.)
class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
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

        let window = KeyableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 780),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.level = .normal
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = true
        window.hasShadow = false
        window.contentView = hostingView
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.invalidateShadow()
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }
}
