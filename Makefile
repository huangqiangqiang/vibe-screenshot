APP_NAME := ScreenshotTool
APP_EXECUTABLE := ScreenshotTool
EXTENSION_NAME := ScreenshotCompanionExtension
CONFIGURATION := release
BIN_DIR := $(shell swift build -c $(CONFIGURATION) --show-bin-path)
DIST_DIR := dist
APP_BUNDLE := $(DIST_DIR)/$(APP_NAME).app
EXTENSION_BUNDLE := $(APP_BUNDLE)/Contents/PlugIns/$(EXTENSION_NAME).appex
ICONSET_DIR := $(DIST_DIR)/AppIcon.iconset
APP_ICON := $(DIST_DIR)/AppIcon.icns

.PHONY: all build app run verify clean

all: app

build:
	swift build -c $(CONFIGURATION)

app: build
	rm -rf "$(APP_BUNDLE)"
	rm -rf "$(ICONSET_DIR)" "$(APP_ICON)"
	swift Support/generate_app_icon.swift "$(ICONSET_DIR)"
	iconutil -c icns "$(ICONSET_DIR)" -o "$(APP_ICON)"
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	mkdir -p "$(APP_BUNDLE)/Contents/PlugIns"
	mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	cp Support/AppInfo.plist "$(APP_BUNDLE)/Contents/Info.plist"
	cp "$(APP_ICON)" "$(APP_BUNDLE)/Contents/Resources/AppIcon.icns"
	cp "$(BIN_DIR)/$(APP_EXECUTABLE)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_EXECUTABLE)"
	chmod +x "$(APP_BUNDLE)/Contents/MacOS/$(APP_EXECUTABLE)"
	mkdir -p "$(EXTENSION_BUNDLE)/Contents/MacOS"
	cp Support/ExtensionInfo.plist "$(EXTENSION_BUNDLE)/Contents/Info.plist"
	cp "$(BIN_DIR)/$(EXTENSION_NAME)" "$(EXTENSION_BUNDLE)/Contents/MacOS/$(EXTENSION_NAME)"
	chmod +x "$(EXTENSION_BUNDLE)/Contents/MacOS/$(EXTENSION_NAME)"
	codesign --force --timestamp=none --sign - "$(EXTENSION_BUNDLE)"
	codesign --force --timestamp=none --sign - "$(APP_BUNDLE)"

run: app
	open "$(APP_BUNDLE)"

verify: app
	plutil -lint "$(APP_BUNDLE)/Contents/Info.plist"
	plutil -lint "$(EXTENSION_BUNDLE)/Contents/Info.plist"
	codesign --verify --deep --strict "$(APP_BUNDLE)"

clean:
	rm -rf "$(DIST_DIR)"
	swift package clean
