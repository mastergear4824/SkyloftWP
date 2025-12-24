#!/bin/bash

# Build SkyloftWP Screen Saver
# This script compiles the screen saver bundle

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SAVER_DIR="$PROJECT_DIR/ScreenSaver"
BUILD_DIR="$PROJECT_DIR/build/ScreenSaver"
OUTPUT_NAME="SkyloftWPSaver"

echo "🎬 Building Skyloft WP Screen Saver..."

# Create build directory
mkdir -p "$BUILD_DIR"

# Create bundle structure
BUNDLE_DIR="$BUILD_DIR/$OUTPUT_NAME.saver"
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
mkdir -p "$BUNDLE_DIR/Contents/Resources"

# Copy Info.plist
cp "$SAVER_DIR/Info.plist" "$BUNDLE_DIR/Contents/"

# Compile Swift code
echo "📦 Compiling Swift code..."

swiftc \
    -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
    -target arm64-apple-macos12.0 \
    -module-name "$OUTPUT_NAME" \
    -emit-executable \
    -o "$BUNDLE_DIR/Contents/MacOS/$OUTPUT_NAME" \
    -framework ScreenSaver \
    -framework AVFoundation \
    -framework AVKit \
    -framework AppKit \
    "$SAVER_DIR/SkyloftScreenSaverView.swift"

# Sign the bundle (ad-hoc)
echo "🔐 Signing bundle..."
codesign --force --deep --sign - "$BUNDLE_DIR"

# Copy to app Resources for embedding
APP_RESOURCES="$PROJECT_DIR/SkyloftWP/Resources"
mkdir -p "$APP_RESOURCES/ScreenSaver"
cp -R "$BUNDLE_DIR" "$APP_RESOURCES/ScreenSaver/"

echo "✅ Screen Saver built successfully!"
echo "📍 Location: $BUNDLE_DIR"
echo ""
echo "To install manually:"
echo "  cp -R \"$BUNDLE_DIR\" ~/Library/Screen\\ Savers/"
