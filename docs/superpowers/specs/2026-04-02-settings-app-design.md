# Settings App Redesign

## Overview

Replace the current minimal `SettingsView` (350x300 Form) and scattered menu bar setting controls with a single, well-designed settings window. The menu bar simplifies to: session list, divider, "Settings...", "Quit AgentCh".

## Window

- **Size:** ~450w x ~580h, non-resizable
- **Title:** "AgentCh Settings"
- **Layout:** Vertical `ScrollView` with ~16pt spacing between sections
- **Bottom:** Centered "AgentCh v1.x" version label in `.caption` secondary text

## Section styling

Each section is a rounded-rect container:
- Background: `.fill(.primary.opacity(0.04))`
- Internal padding: ~16pt
- Corner radius: ~12pt
- Header: SF Symbol icon + title in `.headline` weight, left-aligned
- Controls: Right-aligned values/toggles, left-aligned labels

## Section 1: General

Header: `gearshape` + "General"

| Setting | Control | Notes |
|---|---|---|
| Launch at Login | Toggle (right-aligned) | Uses `SMAppService` as today |
| HTTP Port | Compact number field | Caption below: "Requires restart" |

## Section 2: Appearance

Header: `paintbrush` + "Appearance"

| Setting | Control | Notes |
|---|---|---|
| Pill Size | Horizontal slider (0.5x - 2.0x, default 1.0x) | Mini pill preview to the right that scales live with the slider value |
| Collapse Duration | Horizontal slider (1s - 10s, default 2.5s) | Label to the right showing current value like "2.5s" |

**Pill Size** introduces a new `@AppStorage("pillScale")` CGFloat (default 1.0). The `PillGroupView` applies `.scaleEffect(pillScale)` to the pill body. The mini preview in settings renders a static collapsed pill (mascot + status dot) at the selected scale.

**Collapse Duration** replaces the hardcoded `peekDuration` constant in `PillGroupView` with an `@AppStorage("peekDuration")` Double (default 2.5).

## Section 3: Sound

Header: `speaker.wave.2` + "Sound"

A styled picker/dropdown showing the currently selected sound name. Clicking opens a popover or menu listing all available sounds. Each row shows the sound name. Clicking any row plays a preview immediately. The selected row has a checkmark. Backed by existing `@AppStorage("notificationSound")`.

## Section 4: Position

Header: `rectangle.inset.filled` + "Position"

**3x3 grid:** 9 small rounded-rect cells arranged in a square. Each cell represents a `PillScreenPosition` (top-left through bottom-right). The currently active position is highlighted with accent color and a filled dot. Click any cell to move the pill there (calls `pillPosition.moveTo()`). Cells have subtle hover highlights.

Determining the "current" position: compare `pillPosition.offset` against `pillPosition.offsetFor()` for each of the 9 positions. The closest match is highlighted.

**Display picker:** Below the grid, a dropdown showing the current screen name, listing all connected displays. Selecting one updates `screenManager.selectedScreenIndex`.

## Section 5: Hooks

Header: `link` + "Hooks"

**Global toggle:** "Enable Hooks" switch at the top. When disabled (hooks disabled), the section content below is grayed out and non-interactive. Backed by existing `@AppStorage("hooksDisabled")`.

**Agent rows:** One row per `AgentHookConfig.all` entry. Each row shows:
- Agent name
- Install status: green "Installed" or gray "Not Installed" label
- Toggle to install/uninstall that agent's hooks

**Bulk actions:** Two compact text buttons at the bottom: "Install All" and "Uninstall All".

## Menu bar changes

`MenuBarView` simplifies to:

1. Session list (existing `ForEach` with jump-to-terminal buttons)
2. Divider
3. "Settings..." button (opens the new settings window)
4. "Quit AgentCh" button with `Cmd+Q` shortcut

All removed from menu bar: Sound submenu, Position submenu, Display submenu, Hooks submenu, Enable/Disable Hooks button. These all move into the settings window.

## Files to modify

| File | Change |
|---|---|
| `Views/SettingsView.swift` | Rewrite entirely — new sectioned layout, new controls, keep `SettingsWindowController` |
| `Views/MenuBarView.swift` | Strip down to sessions + settings + quit |
| `Views/PillGroupView.swift` | Read `pillScale` from `@AppStorage`, apply `.scaleEffect()`. Replace hardcoded `peekDuration` with `@AppStorage`. |
| `Models/PillPosition.swift` | No changes needed — `moveTo()` and `offsetFor()` already exist |
| `agentchApp.swift` | Pass `screenManager` and `pillPosition` to `SettingsWindowController` so the settings window can interact with them |

## New files

None. All changes fit in existing files.

## New `@AppStorage` keys

| Key | Type | Default | Purpose |
|---|---|---|---|
| `pillScale` | CGFloat | 1.0 | Pill size multiplier |
| `peekDuration` | Double | 2.5 | Seconds before expanded pill auto-collapses |

## Testing

- Verify all settings persist across app restarts
- Verify pill size slider updates the live pill immediately
- Verify collapse duration slider changes the peek timing
- Verify 3x3 grid highlights the correct current position
- Verify sound picker plays preview on selection
- Verify hook install/uninstall toggles work per-agent
- Verify menu bar no longer has settings submenus
- Verify settings window is reusable (opening twice doesn't create a second window)
