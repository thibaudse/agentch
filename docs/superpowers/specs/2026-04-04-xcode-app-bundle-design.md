# Migrate to Xcode Project with .app Bundle

## Goal

Replace the SPM bare-binary build with a proper Xcode project that produces `AgentCh.app`. This makes `SMAppService` launch-at-login work, gives a real app icon in Dock/Launchpad, and is the standard macOS distribution format.

## Bundle Identity

- **Bundle ID:** `com.thibaudse.agentch`
- **Display name:** AgentCh
- **Target:** macOS 15+
- **Swift:** 6.0
- **LSUIElement:** true (menu bar app, no Dock icon)

## What Changes

### Add

- **`AgentCh.xcodeproj`** — Xcode project with a single macOS App target. References existing source files in `agentch_pkg/agentch/`.
- **`agentch_pkg/agentch/Assets.xcassets/`** — Asset catalog containing `AppIcon.appiconset` generated from `support/icon.svg`. Needs 1024x1024, 512x512@2x, 512x512, 256x256@2x, 256x256, 128x128@2x, 128x128, 32x32@2x, 32x32, 16x16@2x, 16x16 PNGs.
- **Updated `Info.plist`** — Add full bundle metadata:
  - `CFBundleIdentifier`: `com.thibaudse.agentch`
  - `CFBundleExecutable`: `AgentCh`
  - `CFBundleName`: `AgentCh`
  - `CFBundleDisplayName`: `AgentCh`
  - `CFBundleVersion`: `1`
  - `CFBundleShortVersionString`: `1.0`
  - `CFBundlePackageType`: `APPL`
  - `LSUIElement`: `true`
  - `CFBundleIconFile`: `AppIcon`

### Remove

- **`Package.swift`** — SPM package definition, replaced by Xcode project.
- **`LaunchdHelper.swift`** — Launchd plist approach for launch-at-login. `SMAppService.mainApp` handles this now that we have a real .app bundle.
- **`--launchd`/`--unlaunchd` CLI handling** in `agentchApp.init()` — No longer needed.
- **`support/com.agentch.plist`** — Launchd plist template, no longer needed.
- **Sandbox entitlement** (`com.apple.security.app-sandbox`) — Not needed for non-App Store distribution. The app needs unrestricted localhost server and filesystem access for hooks. Keep the entitlements file but only with network entitlements if needed, or remove entirely.

### Update

- **`Makefile`** — Replace `swift build` with `xcodebuild`. Add targets:
  - `build`: `xcodebuild -project AgentCh.xcodeproj -scheme AgentCh -configuration Release build`
  - `install`: Copy `.app` to `/Applications/AgentCh.app`
  - `uninstall`: Remove from `/Applications` and clean up hooks
  - Remove `launchd`/`unlaunchd` targets
- **`install.sh`** — Update to download `.app.zip` from GitHub releases, unzip to `/Applications`.
- **`agentchApp.swift`** — Remove the `init()` block that handles `--launchd`/`--unlaunchd` flags.

### Keep As-Is

- All existing Swift source files (views, models, server, hooks) — just referenced by Xcode project instead of SPM.
- `SMAppService.mainApp.register()/unregister()` in `SettingsView.swift` — this is the correct API and will now work with a real .app bundle.
- `support/icon.svg` — kept as source asset.

## Project Structure

```
AgentCh.xcodeproj/
agentch_pkg/
  agentch/
    agentchApp.swift        (entry point, @main)
    Info.plist              (updated with full bundle metadata)
    agentch.entitlements    (remove sandbox, keep minimal or delete)
    Assets.xcassets/        (NEW - app icon)
    Models/
    Views/
    Hooks/
    Server/
    ...
support/
  icon.svg                  (source icon)
Makefile                    (updated for xcodebuild)
install.sh                  (updated for .app distribution)
```

## App Icon Pipeline

1. Convert `support/icon.svg` to 1024x1024 PNG using `sips` or `rsvg-convert`
2. Generate all required icon sizes from the 1024 source
3. Create `Assets.xcassets/AppIcon.appiconset/Contents.json` with proper size mappings
4. Xcode bundles this into the .app automatically

## Build & Install Flow

```
make build    → xcodebuild produces AgentCh.app in build/
make install  → copies AgentCh.app to /Applications/
```

## Launch-at-Login

With a proper .app bundle and `com.thibaudse.agentch` bundle ID, `SMAppService.mainApp.register()` registers the app as a login item through the system Login Items mechanism. Users see it in System Settings > General > Login Items. No launchd plist management needed.

## Release Distribution

Update GitHub Actions (if any) to:
1. Build with `xcodebuild`
2. Zip the `.app` bundle
3. Upload `AgentCh.app.zip` as release asset
4. `install.sh` downloads and unzips to `/Applications`
