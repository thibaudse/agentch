APP_NAME = AgentCh
APP_DIR = /Applications

.PHONY: build install uninstall clean generate dmg

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

dmg: build
	@rm -rf build/dmg $(APP_NAME).dmg
	@mkdir -p build/dmg
	@cp -R "build/Release/$(APP_NAME).app" build/dmg/
	@ln -s /Applications build/dmg/Applications
	@hdiutil create -volname "$(APP_NAME)" -srcfolder build/dmg -ov -format UDBZ "$(APP_NAME).dmg"
	@echo "Created $(APP_NAME).dmg"

clean:
	@rm -rf build DerivedData $(APP_NAME).xcodeproj $(APP_NAME).dmg
