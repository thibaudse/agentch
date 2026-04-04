# Xcode App Bundle Migration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace SPM bare-binary build with a proper Xcode project producing `AgentCh.app`, enabling SMAppService launch-at-login and standard macOS app distribution.

**Architecture:** XcodeGen generates `.xcodeproj` from a declarative `project.yml`. Source files stay in `agentch_pkg/agentch/`. The `.xcodeproj` is gitignored (generated artifact). Build via `make build` which runs `xcodegen generate && xcodebuild`.

**Tech Stack:** Xcode 16+, Swift 6, macOS 15+, XcodeGen (brew), sips (built-in macOS)

**Spec:** `docs/superpowers/specs/2026-04-04-xcode-app-bundle-design.md`

---

### Task 1: Remove LaunchdHelper and CLI flag handling

**Files:**
- Delete: `agentch_pkg/agentch/Hooks/LaunchdHelper.swift`
- Modify: `agentch_pkg/agentch/agentchApp.swift:11-21`

- [ ] **Step 1: Delete LaunchdHelper.swift**

```bash
rm agentch_pkg/agentch/Hooks/LaunchdHelper.swift
```

- [ ] **Step 2: Remove CLI flag handling from agentchApp.swift**

Remove the entire `init()` block from the `agentchApp` struct. The struct should have no `init()` — just the `@NSApplicationDelegateAdaptor` and `body`.

After edit, `agentchApp` should look like:

```swift
@main
struct agentchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("agentch", systemImage: "bubble.left.and.bubble.right.fill") {
            MenuBarView(sessionManager: appDelegate.sessionManager)
        }
        .menuBarExtraStyle(.menu)
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "refactor: remove LaunchdHelper and CLI flag handling

SMAppService replaces launchd plist approach now that we have a proper .app bundle."
```

---

### Task 2: Remove sandbox entitlements

**Files:**
- Delete: `agentch_pkg/agentch/agentch.entitlements`

- [ ] **Step 1: Delete the entitlements file**

The app needs unrestricted localhost server and filesystem access (for hook configs in `~/.claude/`). Without App Store distribution, sandbox is unnecessary.

```bash
rm agentch_pkg/agentch/agentch.entitlements
```

- [ ] **Step 2: Commit**

```bash
git add -A && git commit -m "chore: remove sandbox entitlements

Non-App Store app doesn't need sandbox. Removes restrictions on localhost server and filesystem access."
```

---

### Task 3: Update Info.plist with full bundle metadata

**Files:**
- Modify: `agentch_pkg/agentch/Info.plist`

- [ ] **Step 1: Replace Info.plist contents**

The current Info.plist only has `LSUIElement`. Replace with full bundle metadata:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundleDisplayName</key>
    <string>AgentCh</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>$(MACOSX_DEPLOYMENT_TARGET)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
```

Note: `$(PRODUCT_BUNDLE_IDENTIFIER)`, `$(EXECUTABLE_NAME)`, etc. are Xcode build setting variables resolved at build time.

- [ ] **Step 2: Commit**

```bash
git add agentch_pkg/agentch/Info.plist && git commit -m "chore: update Info.plist with full bundle metadata"
```

---

### Task 4: Generate app icon assets

**Files:**
- Create: `agentch_pkg/agentch/Assets.xcassets/Contents.json`
- Create: `agentch_pkg/agentch/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `agentch_pkg/agentch/Assets.xcassets/AppIcon.appiconset/icon_1024x1024.png`
- Create: `agentch_pkg/agentch/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png`
- Create: `agentch_pkg/agentch/Assets.xcassets/AppIcon.appiconset/icon_512x512.png`
- Create: `agentch_pkg/agentch/Assets.xcassets/AppIcon.appiconset/icon_256x256@2x.png`
- Create: `agentch_pkg/agentch/Assets.xcassets/AppIcon.appiconset/icon_256x256.png`
- Create: `agentch_pkg/agentch/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png`
- Create: `agentch_pkg/agentch/Assets.xcassets/AppIcon.appiconset/icon_128x128.png`
- Create: `agentch_pkg/agentch/Assets.xcassets/AppIcon.appiconset/icon_32x32@2x.png`
- Create: `agentch_pkg/agentch/Assets.xcassets/AppIcon.appiconset/icon_32x32.png`
- Create: `agentch_pkg/agentch/Assets.xcassets/AppIcon.appiconset/icon_16x16@2x.png`
- Create: `agentch_pkg/agentch/Assets.xcassets/AppIcon.appiconset/icon_16x16.png`

- [ ] **Step 1: Create asset catalog directory structure**

```bash
mkdir -p agentch_pkg/agentch/Assets.xcassets/AppIcon.appiconset
```

- [ ] **Step 2: Convert SVG to 1024x1024 PNG**

Use `rsvg-convert` (install with `brew install librsvg` if not available):

```bash
rsvg-convert -w 1024 -h 1024 support/icon.svg -o agentch_pkg/agentch/Assets.xcassets/AppIcon.appiconset/icon_1024x1024.png
```

If `rsvg-convert` is not available, use `qlmanage` (built-in):

```bash
qlmanage -t -s 1024 -o /tmp/ support/icon.svg && sips -s format png /tmp/icon.svg.png --out agentch_pkg/agentch/Assets.xcassets/AppIcon.appiconset/icon_1024x1024.png
```

- [ ] **Step 3: Generate all icon sizes from 1024 source**

```bash
cd agentch_pkg/agentch/Assets.xcassets/AppIcon.appiconset
SOURCE=icon_1024x1024.png
sips -z 1024 1024 $SOURCE --out icon_512x512@2x.png
sips -z 512 512 $SOURCE --out icon_512x512.png
sips -z 512 512 $SOURCE --out icon_256x256@2x.png
sips -z 256 256 $SOURCE --out icon_256x256.png
sips -z 256 256 $SOURCE --out icon_128x128@2x.png
sips -z 128 128 $SOURCE --out icon_128x128.png
sips -z 64 64 $SOURCE --out icon_32x32@2x.png
sips -z 32 32 $SOURCE --out icon_32x32.png
sips -z 32 32 $SOURCE --out icon_16x16@2x.png
sips -z 16 16 $SOURCE --out icon_16x16.png
cd -
```

- [ ] **Step 4: Create asset catalog Contents.json files**

`agentch_pkg/agentch/Assets.xcassets/Contents.json`:
```json
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

`agentch_pkg/agentch/Assets.xcassets/AppIcon.appiconset/Contents.json`:
```json
{
  "images" : [
    {
      "filename" : "icon_16x16.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_16x16@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_32x32.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_32x32@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_128x128.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_128x128@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_256x256.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_256x256@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_512x512.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "icon_512x512@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    },
    {
      "filename" : "icon_1024x1024.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

- [ ] **Step 5: Commit**

```bash
git add agentch_pkg/agentch/Assets.xcassets && git commit -m "feat: add app icon asset catalog

Generated from support/icon.svg at all required macOS icon sizes."
```

---

### Task 5: Create XcodeGen project.yml

**Files:**
- Create: `project.yml`

- [ ] **Step 1: Install XcodeGen if needed**

```bash
which xcodegen || brew install xcodegen
```

- [ ] **Step 2: Create project.yml**

```yaml
name: AgentCh
options:
  bundleIdPrefix: com.thibaudse
  deploymentTarget:
    macOS: "15.0"
  minimumXcodeGenVersion: "2.38"
  generateEmptyDirectories: false

settings:
  base:
    SWIFT_VERSION: "6.0"
    MACOSX_DEPLOYMENT_TARGET: "15.0"

targets:
  AgentCh:
    type: application
    platform: macOS
    sources:
      - path: agentch_pkg/agentch
        excludes:
          - "**/*.entitlements"
    settings:
      base:
        INFOPLIST_FILE: agentch_pkg/agentch/Info.plist
        PRODUCT_BUNDLE_IDENTIFIER: com.thibaudse.agentch
        PRODUCT_NAME: AgentCh
        GENERATE_INFOPLIST_FILE: false
        CODE_SIGN_IDENTITY: "-"
        CODE_SIGN_STYLE: Manual
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
```

`CODE_SIGN_IDENTITY: "-"` means ad-hoc signing (no Apple Developer account needed). `CODE_SIGN_STYLE: Manual` prevents Xcode from trying automatic signing.

- [ ] **Step 3: Generate xcodeproj to verify**

```bash
xcodegen generate
```

Expected output: `⚙ Generating plists...` then `Created project AgentCh.xcodeproj`

- [ ] **Step 4: Verify the project builds**

```bash
xcodebuild -project AgentCh.xcodeproj -scheme AgentCh -configuration Release build SYMROOT=build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add project.yml && git commit -m "feat: add XcodeGen project.yml for .app bundle

Generates AgentCh.xcodeproj with macOS app target. The .xcodeproj is
gitignored (generated artifact)."
```

---

### Task 6: Update build and install tooling

**Files:**
- Modify: `Makefile`
- Modify: `.gitignore`
- Modify: `install.sh`
- Delete: `Package.swift`
- Delete: `support/com.agentch.plist`

- [ ] **Step 1: Update .gitignore**

Replace contents with:

```
# Xcode
*.xcodeproj/
DerivedData/
build/

# Old SPM artifacts
.build/
.swiftpm/
```

The `.xcodeproj` stays gitignored because it's generated by XcodeGen from `project.yml`.

- [ ] **Step 2: Update Makefile**

Replace contents with:

```makefile
APP_NAME = AgentCh
APP_DIR = /Applications

.PHONY: build install uninstall clean generate

generate:
	@which xcodegen > /dev/null || (echo "Install xcodegen: brew install xcodegen" && exit 1)
	xcodegen generate

build: generate
	xcodebuild -project $(APP_NAME).xcodeproj -scheme $(APP_NAME) -configuration Release build SYMROOT=build 2>&1 | tail -3

install: build
	@rm -rf "$(APP_DIR)/$(APP_NAME).app"
	@cp -R "build/Release/$(APP_NAME).app" "$(APP_DIR)/$(APP_NAME).app"
	@echo "Installed $(APP_NAME).app to $(APP_DIR)/"
	@echo "Open from Applications or Spotlight."

uninstall:
	@rm -rf "$(APP_DIR)/$(APP_NAME).app"
	@echo "Uninstalled $(APP_NAME).app"

clean:
	@rm -rf build DerivedData $(APP_NAME).xcodeproj
```

- [ ] **Step 3: Update install.sh**

Replace contents with:

```bash
#!/bin/bash
set -e

REPO="thibaudse/agentch"
APP_NAME="AgentCh"
INSTALL_DIR="/Applications"

echo "Installing $APP_NAME..."

# Get latest release URL
DOWNLOAD_URL=$(curl -sL "https://api.github.com/repos/$REPO/releases/latest" \
    | grep "browser_download_url.*$APP_NAME.app.zip" \
    | cut -d '"' -f 4)

if [ -z "$DOWNLOAD_URL" ]; then
    echo "No release found. Building from source..."
    
    # Check for xcodegen
    if ! command -v xcodegen &> /dev/null; then
        echo "Installing xcodegen..."
        brew install xcodegen
    fi
    
    TMPDIR=$(mktemp -d)
    git clone --depth 1 "https://github.com/$REPO.git" "$TMPDIR/agentch"
    cd "$TMPDIR/agentch"
    make install
    rm -rf "$TMPDIR"
else
    # Download and install .app
    TMPDIR=$(mktemp -d)
    curl -sL "$DOWNLOAD_URL" -o "$TMPDIR/$APP_NAME.app.zip"
    unzip -q "$TMPDIR/$APP_NAME.app.zip" -d "$TMPDIR"
    rm -rf "$INSTALL_DIR/$APP_NAME.app"
    cp -R "$TMPDIR/$APP_NAME.app" "$INSTALL_DIR/$APP_NAME.app"
    rm -rf "$TMPDIR"
fi

echo "Installed to $INSTALL_DIR/$APP_NAME.app"
echo ""
echo "Open AgentCh from Applications or Spotlight."
echo "Enable 'Launch at Login' in the app's settings."
```

- [ ] **Step 4: Remove old SPM and launchd files**

```bash
rm Package.swift support/com.agentch.plist
```

- [ ] **Step 5: Build and verify the full flow**

```bash
make clean && make build
```

Expected: `** BUILD SUCCEEDED **`

Verify the .app exists:

```bash
ls -la build/Release/AgentCh.app/Contents/MacOS/AgentCh
ls -la build/Release/AgentCh.app/Contents/Info.plist
ls -la build/Release/AgentCh.app/Contents/Resources/AppIcon.icns
```

All three should exist.

- [ ] **Step 6: Test launch**

```bash
open build/Release/AgentCh.app
```

The menu bar icon should appear. Open settings and toggle "Launch at Login" — it should register without error (check Console.app for `SMAppService` messages if needed).

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat: migrate to Xcode project with .app bundle

- XcodeGen project.yml replaces Package.swift
- Proper .app bundle enables SMAppService launch-at-login
- Makefile uses xcodebuild, installs to /Applications
- Removed LaunchdHelper, sandbox entitlements, launchd plist"
```

---

### Task 7: Install and smoke test

- [ ] **Step 1: Install to /Applications**

```bash
make install
```

Expected: `Installed AgentCh.app to /Applications/`

- [ ] **Step 2: Launch from Applications**

```bash
open /Applications/AgentCh.app
```

Verify:
1. Menu bar icon appears
2. Settings window opens (click menu bar icon > Settings)
3. "Launch at Login" toggle works without error
4. HTTP server responds: `curl -s http://localhost:27182/health` (or send a test event)

- [ ] **Step 3: Verify launch-at-login**

Toggle "Launch at Login" ON in settings. Check System Settings > General > Login Items — AgentCh should appear in the list.
