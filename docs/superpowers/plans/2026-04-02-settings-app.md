# Settings App Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the minimal settings window and scattered menu bar controls with a single, well-designed settings app featuring visual previews.

**Architecture:** Rewrite `SettingsView.swift` as a scrollable single-page layout with 5 styled sections. Simplify `MenuBarView` to sessions + settings + quit. Wire two new `@AppStorage` keys (`pillScale`, `peekDuration`) into `PillGroupView`. Pass `pillPosition` and `screenManager` into the settings window via `SettingsWindowController`.

**Tech Stack:** SwiftUI, AppKit (NSWindow), `@AppStorage`, `SMAppService`

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `agentch_pkg/agentch/Views/SettingsView.swift` | Rewrite | New sectioned settings UI + `SettingsWindowController` updates |
| `agentch_pkg/agentch/Views/MenuBarView.swift` | Modify | Strip to sessions + settings + quit |
| `agentch_pkg/agentch/Views/PillGroupView.swift` | Modify | Read `pillScale` and `peekDuration` from `@AppStorage` |
| `agentch_pkg/agentch/agentchApp.swift` | Modify | Pass dependencies to `SettingsWindowController` |

---

### Task 1: Wire @AppStorage keys into PillGroupView

**Files:**
- Modify: `agentch_pkg/agentch/Views/PillGroupView.swift:3,15,67,89`

- [ ] **Step 1: Add @AppStorage properties**

At the top of `PillGroupView` (after line 3, before the existing `@State` properties), add:

```swift
@AppStorage("pillScale") var pillScale: Double = 1.0
@AppStorage("peekDuration") var peekDurationSetting: Double = 2.5
```

- [ ] **Step 2: Replace hardcoded peekDuration**

Remove the existing constant on line 15:
```swift
private let peekDuration: TimeInterval = 2.5
```

The `peekDurationSetting` property now serves this role. Update the one reference in the `peek()` method (line 141) from:
```swift
try? await Task.sleep(for: .seconds(peekDuration))
```
to:
```swift
try? await Task.sleep(for: .seconds(peekDurationSetting))
```

- [ ] **Step 3: Apply pillScale to the pill body**

In the `body` computed property, find the `.scaleEffect(squish)` line (line 89) and change it to:
```swift
.scaleEffect(squish * pillScale)
```

- [ ] **Step 4: Build and verify**

Run:
```bash
cd /Users/thibaud/Projects/Personal/agentch && swift build 2>&1 | tail -5
```
Expected: Build succeeds with no errors.

- [ ] **Step 5: Commit**

```bash
git add agentch_pkg/agentch/Views/PillGroupView.swift
git commit -m "feat: wire pillScale and peekDuration into PillGroupView via @AppStorage"
```

---

### Task 2: Update SettingsWindowController to accept dependencies

**Files:**
- Modify: `agentch_pkg/agentch/Views/SettingsView.swift:57-87`
- Modify: `agentch_pkg/agentch/agentchApp.swift:96`

- [ ] **Step 1: Update SettingsWindowController**

Replace the `SettingsWindowController` class (lines 57-87 in `SettingsView.swift`) with:

```swift
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
        window.title = "AgentCh Settings"
        window.contentView = hostingView
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }
}
```

- [ ] **Step 2: Wire dependencies in AppDelegate**

In `agentchApp.swift`, add the following at the end of `applicationDidFinishLaunching` (after `sessionManager.startCleanup()` on line 49):

```swift
SettingsWindowController.shared.pillPosition = pillPosition
SettingsWindowController.shared.screenManager = screenManager
```

- [ ] **Step 3: Update SettingsView struct signature temporarily**

Temporarily update the `SettingsView` struct to accept the new parameters so the project compiles. Replace lines 1-42 of `SettingsView.swift` with:

```swift
import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var pillPosition: PillPosition
    @ObservedObject var screenManager: ScreenManager
    @AppStorage("httpPort") var httpPort: Int = 27182
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false

    var body: some View {
        Text("Settings placeholder")
            .frame(width: 450, height: 580)
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
```

- [ ] **Step 4: Build and verify**

Run:
```bash
cd /Users/thibaud/Projects/Personal/agentch && swift build 2>&1 | tail -5
```
Expected: Build succeeds.

- [ ] **Step 5: Commit**

```bash
git add agentch_pkg/agentch/Views/SettingsView.swift agentch_pkg/agentch/agentchApp.swift
git commit -m "refactor: update SettingsWindowController to accept pillPosition and screenManager"
```

---

### Task 3: Build the section container and General section

**Files:**
- Modify: `agentch_pkg/agentch/Views/SettingsView.swift`

- [ ] **Step 1: Write the SettingsSection helper and General section**

Replace the entire `SettingsView` struct body (keep the properties and `updateLaunchAtLogin` method) with:

```swift
struct SettingsView: View {
    @ObservedObject var pillPosition: PillPosition
    @ObservedObject var screenManager: ScreenManager
    @AppStorage("httpPort") var httpPort: Int = 27182
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                generalSection
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
```

- [ ] **Step 2: Build and verify**

Run:
```bash
cd /Users/thibaud/Projects/Personal/agentch && swift build 2>&1 | tail -5
```
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add agentch_pkg/agentch/Views/SettingsView.swift
git commit -m "feat: settings section container and General section"
```

---

### Task 4: Add Appearance section

**Files:**
- Modify: `agentch_pkg/agentch/Views/SettingsView.swift`

- [ ] **Step 1: Add Appearance section**

Add two new `@AppStorage` properties to `SettingsView`, alongside the existing ones:

```swift
@AppStorage("pillScale") var pillScale: Double = 1.0
@AppStorage("peekDuration") var peekDuration: Double = 2.5
```

Add `appearanceSection` to the `VStack` in `body` (after `generalSection`):

```swift
appearanceSection
```

Add the section implementation after `generalSection`:

```swift
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
```

- [ ] **Step 2: Build and verify**

Run:
```bash
cd /Users/thibaud/Projects/Personal/agentch && swift build 2>&1 | tail -5
```
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add agentch_pkg/agentch/Views/SettingsView.swift
git commit -m "feat: Appearance section with pill size slider and collapse duration"
```

---

### Task 5: Add Sound section

**Files:**
- Modify: `agentch_pkg/agentch/Views/SettingsView.swift`

- [ ] **Step 1: Add Sound section**

Add an `@AppStorage` property to `SettingsView`:

```swift
@AppStorage("notificationSound") var selectedSound: String = "Blow"
```

Add `soundSection` to the `VStack` in `body` (after `appearanceSection`):

```swift
soundSection
```

Add the section implementation:

```swift
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
```

- [ ] **Step 2: Build and verify**

Run:
```bash
cd /Users/thibaud/Projects/Personal/agentch && swift build 2>&1 | tail -5
```
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add agentch_pkg/agentch/Views/SettingsView.swift
git commit -m "feat: Sound section with picker and preview on selection"
```

---

### Task 6: Add Position section with 3x3 grid

**Files:**
- Modify: `agentch_pkg/agentch/Views/SettingsView.swift`

- [ ] **Step 1: Add Position section and grid**

Add `positionSection` to the `VStack` in `body` (after `soundSection`):

```swift
positionSection
```

Add the section implementation:

```swift
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
```

- [ ] **Step 2: Build and verify**

Run:
```bash
cd /Users/thibaud/Projects/Personal/agentch && swift build 2>&1 | tail -5
```
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add agentch_pkg/agentch/Views/SettingsView.swift
git commit -m "feat: Position section with 3x3 visual grid and display picker"
```

---

### Task 7: Add Hooks section

**Files:**
- Modify: `agentch_pkg/agentch/Views/SettingsView.swift`

- [ ] **Step 1: Add Hooks section**

Add an `@AppStorage` property to `SettingsView`:

```swift
@AppStorage("hooksDisabled") var hooksDisabled: Bool = false
```

Add `hooksSection` to the `VStack` in `body` (after `positionSection`):

```swift
hooksSection
```

Add a version label at the bottom of the `VStack` (after `hooksSection`):

```swift
Text("AgentCh v1.0")
    .font(.caption)
    .foregroundStyle(.secondary)
    .frame(maxWidth: .infinity)
    .padding(.top, 4)
```

Add the section implementation:

```swift
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
                            }
                        ))
                        .labelsHidden()
                    }
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("Install All") {
                    HookManager.installAll(port: UInt16(httpPort))
                }
                Button("Uninstall All") {
                    HookManager.uninstallAll()
                }
            }
            .font(.caption)
        }
    }
}
```

- [ ] **Step 2: Build and verify**

Run:
```bash
cd /Users/thibaud/Projects/Personal/agentch && swift build 2>&1 | tail -5
```
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add agentch_pkg/agentch/Views/SettingsView.swift
git commit -m "feat: Hooks section with per-agent toggles and bulk actions"
```

---

### Task 8: Simplify MenuBarView

**Files:**
- Modify: `agentch_pkg/agentch/Views/MenuBarView.swift`

- [ ] **Step 1: Strip MenuBarView down**

Replace the entire `MenuBarView` body with:

```swift
struct MenuBarView: View {
    @ObservedObject var sessionManager: SessionManager

    var body: some View {
        if sessionManager.sessions.isEmpty {
            Text("No active sessions")
        } else {
            ForEach(sessionManager.sessions) { session in
                Button {
                    TerminalFocuser.focus(session: session)
                } label: {
                    Text("\(statusEmoji(session.status)) \(session.label) — \(statusText(session.status))")
                }
            }
        }

        Divider()

        Button("Settings...") {
            SettingsWindowController.shared.showWindow()
        }

        Button("Quit AgentCh") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private func statusEmoji(_ status: SessionStatus) -> String {
        switch status {
        case .thinking: return "🟢"
        case .waiting: return "🟠"
        case .idle: return "⚪"
        case .error: return "🔴"
        }
    }

    private func statusText(_ status: SessionStatus) -> String {
        switch status {
        case .thinking: return "working"
        case .waiting: return "needs input"
        case .idle: return "idle"
        case .error: return "error"
        }
    }
}
```

- [ ] **Step 2: Update MenuBarView initializer in agentchApp.swift**

In `agentchApp.swift`, update the `MenuBarExtra` body (line 26) to remove the now-unused parameters:

```swift
MenuBarView(sessionManager: appDelegate.sessionManager)
```

This replaces:
```swift
MenuBarView(sessionManager: appDelegate.sessionManager, screenManager: appDelegate.screenManager, pillPosition: appDelegate.pillPosition)
```

- [ ] **Step 3: Build and verify**

Run:
```bash
cd /Users/thibaud/Projects/Personal/agentch && swift build 2>&1 | tail -5
```
Expected: Build succeeds.

- [ ] **Step 4: Commit**

```bash
git add agentch_pkg/agentch/Views/MenuBarView.swift agentch_pkg/agentch/agentchApp.swift
git commit -m "refactor: simplify MenuBarView to sessions + settings + quit"
```

---

### Task 9: Final build and manual verification

**Files:**
- None (verification only)

- [ ] **Step 1: Clean build**

Run:
```bash
cd /Users/thibaud/Projects/Personal/agentch && swift build 2>&1 | tail -10
```
Expected: Build succeeds with no warnings related to our changes.

- [ ] **Step 2: Verify all @AppStorage keys are consistent**

Grep to confirm no leftover references to removed menu bar settings:

```bash
cd /Users/thibaud/Projects/Personal/agentch && grep -rn "Menu(\"Sound" agentch_pkg/agentch/Views/
grep -rn "Menu(\"Position" agentch_pkg/agentch/Views/
grep -rn "Menu(\"Display" agentch_pkg/agentch/Views/
grep -rn "Menu(\"Hooks" agentch_pkg/agentch/Views/
```
Expected: No matches in `MenuBarView.swift`. Only matches in `SettingsView.swift` if any (there shouldn't be — we use `SettingsSection` not `Menu`).

- [ ] **Step 3: Verify @AppStorage key consistency**

```bash
cd /Users/thibaud/Projects/Personal/agentch && grep -rn '@AppStorage' agentch_pkg/agentch/
```
Expected: `pillScale` and `peekDuration` appear in both `SettingsView.swift` and `PillGroupView.swift`. Other keys (`httpPort`, `launchAtLogin`, `hooksDisabled`, `notificationSound`, `selectedScreenIndex`) appear where expected.

- [ ] **Step 4: Commit (if any fixups were needed)**

Only if changes were made during verification:
```bash
git add -A && git commit -m "fix: address issues found during final verification"
```
