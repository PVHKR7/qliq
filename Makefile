# Qliq build file.
#
# Qliq is a locally built macOS menu-bar dictation app. This Makefile compiles
# the app directly with swiftc; there is no Xcode project and no package
# resolution step.

APP_NAME ?= Qliq
BUNDLE_ID ?= com.pvhkr.qliq
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
CONTENTS = $(APP_BUNDLE)/Contents
MACOS_DIR = $(CONTENTS)/MacOS
RESOURCES = $(CONTENTS)/Resources
empty :=
space := $(empty) $(empty)
APP_EXECUTABLE = $(MACOS_DIR)/$(APP_NAME)
APP_EXECUTABLE_TARGET := $(subst $(space),\ ,$(APP_EXECUTABLE))

SOURCES = $(shell find Sources -name '*.swift' -type f | LC_ALL=C sort)
TEST_RUNNER = $(BUILD_DIR)/QliqTests
ARCH ?= $(shell uname -m)

# Ad-hoc signing by default. Replace with your own identity if you have one; see
# README.md for why this matters for permission prompts.
CODESIGN_IDENTITY ?= -

# SDK pin.
#
# The macOS 27 SDK declares SwiftUI's @State/@Binding/@Environment as external
# macros, and the plugin that expands them ships inside Xcode rather than the
# Command Line Tools. With CLT only, every SwiftUI view fails to compile with
# "plugin for module 'SwiftUIMacros' not found".
#
# macOS 26.5 is the last SDK in the CLT that still declares those attributes as
# property wrappers, so pin it. The app still targets macOS 13; only the SDK used
# to compile is older. Set SDK=... on the command line to override.
CLT_SDK_26 := /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
ifeq ($(wildcard $(CLT_SDK_26)),)
SDK ?= $(shell xcrun --show-sdk-path)
else
SDK ?= $(CLT_SDK_26)
endif

ICON_SOURCE = Resources/AppIcon-Source.png
ICON_ICNS = Resources/AppIcon.icns

.PHONY: all clean run icon test check-sdk

all: $(APP_EXECUTABLE_TARGET)

check-sdk:
	@echo "SDK:  $(SDK)"
	@echo "Arch: $(ARCH)"
	@echo "Sign: $(CODESIGN_IDENTITY)"

$(APP_EXECUTABLE_TARGET): $(SOURCES) Info.plist $(ICON_ICNS)
	@mkdir -p "$(MACOS_DIR)" "$(RESOURCES)"
ifeq ($(ARCH),universal)
	swiftc \
		-parse-as-library \
		-o "$(MACOS_DIR)/$(APP_NAME)-arm64" \
		-sdk $(SDK) \
		-target arm64-apple-macosx13.0 \
		$(SOURCES)
	swiftc \
		-parse-as-library \
		-o "$(MACOS_DIR)/$(APP_NAME)-x86_64" \
		-sdk $(SDK) \
		-target x86_64-apple-macosx13.0 \
		$(SOURCES)
	lipo -create -output "$(MACOS_DIR)/$(APP_NAME)" \
		"$(MACOS_DIR)/$(APP_NAME)-arm64" \
		"$(MACOS_DIR)/$(APP_NAME)-x86_64"
	@rm "$(MACOS_DIR)/$(APP_NAME)-arm64" "$(MACOS_DIR)/$(APP_NAME)-x86_64"
else
	swiftc \
		-parse-as-library \
		-o "$(MACOS_DIR)/$(APP_NAME)" \
		-sdk $(SDK) \
		-target $(ARCH)-apple-macosx13.0 \
		$(SOURCES)
endif
	@cp Info.plist "$(CONTENTS)/"
	@plutil -replace CFBundleName -string "$(APP_NAME)" "$(CONTENTS)/Info.plist"
	@plutil -replace CFBundleDisplayName -string "$(APP_NAME)" "$(CONTENTS)/Info.plist"
	@plutil -replace CFBundleExecutable -string "$(APP_NAME)" "$(CONTENTS)/Info.plist"
	@plutil -replace CFBundleIdentifier -string "$(BUNDLE_ID)" "$(CONTENTS)/Info.plist"
	@plutil -replace NSMicrophoneUsageDescription -string "$(APP_NAME) needs microphone access to transcribe your speech." "$(CONTENTS)/Info.plist"
	@cp $(ICON_ICNS) "$(RESOURCES)/AppIcon.icns"
	@codesign --force --sign "$(CODESIGN_IDENTITY)" --entitlements Qliq.entitlements "$(APP_BUNDLE)"
	@echo "Built $(APP_BUNDLE)"

test: $(TEST_RUNNER)
	@$(TEST_RUNNER)

$(TEST_RUNNER): Sources/AppContextService.swift Sources/LLMAPITransport.swift Sources/ModelConfiguration.swift Tests/AppContextServiceTests.swift
	@mkdir -p "$(BUILD_DIR)"
	swiftc \
		-parse-as-library \
		-o "$(TEST_RUNNER)" \
		-sdk $(SDK) \
		-target $(ARCH)-apple-macosx13.0 \
		Sources/AppContextService.swift Sources/LLMAPITransport.swift Sources/ModelConfiguration.swift Tests/AppContextServiceTests.swift

icon: $(ICON_ICNS)

$(ICON_ICNS): $(ICON_SOURCE)
	@mkdir -p $(BUILD_DIR)/AppIcon.iconset
	@sips -z 16 16 $< --out $(BUILD_DIR)/AppIcon.iconset/icon_16x16.png > /dev/null
	@sips -z 32 32 $< --out $(BUILD_DIR)/AppIcon.iconset/icon_16x16@2x.png > /dev/null
	@sips -z 32 32 $< --out $(BUILD_DIR)/AppIcon.iconset/icon_32x32.png > /dev/null
	@sips -z 64 64 $< --out $(BUILD_DIR)/AppIcon.iconset/icon_32x32@2x.png > /dev/null
	@sips -z 128 128 $< --out $(BUILD_DIR)/AppIcon.iconset/icon_128x128.png > /dev/null
	@sips -z 256 256 $< --out $(BUILD_DIR)/AppIcon.iconset/icon_128x128@2x.png > /dev/null
	@sips -z 256 256 $< --out $(BUILD_DIR)/AppIcon.iconset/icon_256x256.png > /dev/null
	@sips -z 512 512 $< --out $(BUILD_DIR)/AppIcon.iconset/icon_256x256@2x.png > /dev/null
	@sips -z 512 512 $< --out $(BUILD_DIR)/AppIcon.iconset/icon_512x512.png > /dev/null
	@sips -z 1024 1024 $< --out $(BUILD_DIR)/AppIcon.iconset/icon_512x512@2x.png > /dev/null
	@iconutil -c icns -o $@ $(BUILD_DIR)/AppIcon.iconset
	@rm -rf $(BUILD_DIR)/AppIcon.iconset
	@echo "Generated $@"

clean:
	rm -rf $(BUILD_DIR)

run: all
	open "$(APP_BUNDLE)"
