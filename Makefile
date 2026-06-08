APP_NAME      := OpenStackMenu
BUILD_DIR     := .build
RELEASE_BIN   := $(BUILD_DIR)/arm64-apple-macosx/release/$(APP_NAME)
DEBUG_BIN     := $(BUILD_DIR)/arm64-apple-macosx/debug/$(APP_NAME)
APP_BUNDLE    := build/$(APP_NAME).app
CONTENTS_DIR  := $(APP_BUNDLE)/Contents
MACOS_DIR     := $(CONTENTS_DIR)/MacOS
RESOURCES_DIR := $(CONTENTS_DIR)/Resources
ENTITLEMENTS  := Resources/OpenStackMenu.entitlements
LAUNCHAGENT_PLIST := Resources/com.openstackmenu.OpenStackMenu.plist
LAUNCHAGENT_DEST := $(HOME)/Library/LaunchAgents/com.openstackmenu.OpenStackMenu.plist

.PHONY: build debug run clean test install uninstall install-agent uninstall-agent agent-start agent-stop

## Build the app in release mode and create the .app bundle
build:
	swift build -c release
	@mkdir -p $(MACOS_DIR) $(RESOURCES_DIR)
	cp $(RELEASE_BIN) $(MACOS_DIR)/
	cp Resources/Info.plist $(CONTENTS_DIR)/
	cp Resources/askpass.sh $(RESOURCES_DIR)/
	cp Resources/AppIcon.icns $(RESOURCES_DIR)/
	chmod +x $(RESOURCES_DIR)/askpass.sh
	codesign --force --deep --sign - --entitlements $(ENTITLEMENTS) $(APP_BUNDLE)
	@echo "✅ App bundle created at $(APP_BUNDLE)"

## Build the app in debug mode and create the .app bundle
debug:
	swift build
	@mkdir -p $(MACOS_DIR) $(RESOURCES_DIR)
	cp $(DEBUG_BIN) $(MACOS_DIR)/
	cp Resources/Info.plist $(CONTENTS_DIR)/
	cp Resources/askpass.sh $(RESOURCES_DIR)/
	cp Resources/AppIcon.icns $(RESOURCES_DIR)/
	chmod +x $(RESOURCES_DIR)/askpass.sh
	codesign --force --deep --sign - --entitlements $(ENTITLEMENTS) $(APP_BUNDLE)
	@echo "✅ Debug app bundle created at $(APP_BUNDLE)"

## Launch the built app
run: build
	open $(APP_BUNDLE)

## Remove build artifacts
clean:
	rm -rf build/
	swift package clean

## Run tests
test:
	swift test

## Install to /Applications
install: build
	cp -r $(APP_BUNDLE) /Applications/
	@echo "✅ Installed to /Applications/$(APP_NAME).app"
	@echo "   Run 'make install-agent' to enable automatic crash recovery."

## Remove from /Applications
uninstall:
	rm -rf /Applications/$(APP_NAME).app
	@echo "✅ Removed from /Applications"

## Install LaunchAgent for automatic crash recovery
install-agent:
	@mkdir -p $(HOME)/Library/LaunchAgents
	@# Update plist with actual app path
	@if [ -f /Applications/$(APP_NAME).app/Contents/MacOS/$(APP_NAME) ]; then \
		sed "s|/Applications/OpenStackMenu.app|/Applications/$(APP_NAME).app|g" $(LAUNCHAGENT_PLIST) > $(LAUNCHAGENT_DEST); \
	else \
		sed "s|/Applications/OpenStackMenu.app|$(CURDIR)/$(APP_BUNDLE)|g" $(LAUNCHAGENT_PLIST) > $(LAUNCHAGENT_DEST); \
	fi
	@launchctl load -w $(LAUNCHAGENT_DEST) 2>/dev/null || true
	@echo "✅ LaunchAgent installed at $(LAUNCHAGENT_DEST)"
	@echo "   The app will automatically restart if it crashes."

## Remove LaunchAgent
uninstall-agent:
	@launchctl unload -w $(LAUNCHAGENT_DEST) 2>/dev/null || true
	@rm -f $(LAUNCHAGENT_DEST)
	@echo "✅ LaunchAgent removed"

## Start the LaunchAgent (if installed)
agent-start:
	@launchctl load -w $(LAUNCHAGENT_DEST) 2>/dev/null || echo "LaunchAgent not installed. Run 'make install-agent' first."
	@echo "✅ LaunchAgent started"

## Stop the LaunchAgent (if installed)
agent-stop:
	@launchctl unload -w $(LAUNCHAGENT_DEST) 2>/dev/null || echo "LaunchAgent not installed."
	@echo "✅ LaunchAgent stopped"
