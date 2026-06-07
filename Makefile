APP_NAME      := OpenStackMenu
BUILD_DIR     := .build
RELEASE_BIN   := $(BUILD_DIR)/arm64-apple-macosx/release/$(APP_NAME)
DEBUG_BIN     := $(BUILD_DIR)/arm64-apple-macosx/debug/$(APP_NAME)
APP_BUNDLE    := build/$(APP_NAME).app
CONTENTS_DIR  := $(APP_BUNDLE)/Contents
MACOS_DIR     := $(CONTENTS_DIR)/MacOS
RESOURCES_DIR := $(CONTENTS_DIR)/Resources

.PHONY: build debug run clean test install uninstall

## Build the app in release mode and create the .app bundle
build:
	swift build -c release
	@mkdir -p $(MACOS_DIR) $(RESOURCES_DIR)
	cp $(RELEASE_BIN) $(MACOS_DIR)/
	cp Resources/Info.plist $(CONTENTS_DIR)/
	cp Resources/askpass.sh $(RESOURCES_DIR)/
	chmod +x $(RESOURCES_DIR)/askpass.sh
	codesign --force --deep --sign - $(APP_BUNDLE)
	@echo "✅ App bundle created at $(APP_BUNDLE)"

## Build the app in debug mode and create the .app bundle
debug:
	swift build
	@mkdir -p $(MACOS_DIR) $(RESOURCES_DIR)
	cp $(DEBUG_BIN) $(MACOS_DIR)/
	cp Resources/Info.plist $(CONTENTS_DIR)/
	cp Resources/askpass.sh $(RESOURCES_DIR)/
	chmod +x $(RESOURCES_DIR)/askpass.sh
	codesign --force --deep --sign - $(APP_BUNDLE)
	@echo "✅ Debug app bundle created at $(APP_BUNDLE)"

## Launch the built app
run:
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

## Remove from /Applications
uninstall:
	rm -rf /Applications/$(APP_NAME).app
	@echo "✅ Removed from /Applications"
