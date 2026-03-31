PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin
HOOK_DIR = $(HOME)/.agentch

.PHONY: build install uninstall clean

build:
	swift build -c release

install: build
	@mkdir -p $(BINDIR)
	@cp .build/release/agentch $(BINDIR)/agentch
	@echo "Installed agentch to $(BINDIR)/agentch"
	@echo "Run 'agentch' to start, or 'make launchd' to auto-start on login"

uninstall:
	@rm -f $(BINDIR)/agentch
	@rm -rf $(HOOK_DIR)
	@launchctl bootout gui/$$(id -u) ~/Library/LaunchAgents/com.agentch.plist 2>/dev/null || true
	@rm -f ~/Library/LaunchAgents/com.agentch.plist
	@echo "Uninstalled agentch"

launchd:
	@mkdir -p ~/Library/LaunchAgents
	@sed "s|__BINDIR__|$(BINDIR)|g" support/com.agentch.plist > ~/Library/LaunchAgents/com.agentch.plist
	@launchctl bootout gui/$$(id -u) ~/Library/LaunchAgents/com.agentch.plist 2>/dev/null || true
	@launchctl bootstrap gui/$$(id -u) ~/Library/LaunchAgents/com.agentch.plist
	@echo "agentch will start automatically on login"

unlaunchd:
	@launchctl bootout gui/$$(id -u) ~/Library/LaunchAgents/com.agentch.plist 2>/dev/null || true
	@rm -f ~/Library/LaunchAgents/com.agentch.plist
	@echo "Removed agentch from login items"

clean:
	swift package clean
