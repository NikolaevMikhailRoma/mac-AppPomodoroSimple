#!/bin/bash
# Build the SwiftPM executable and package it as a runnable .app bundle.
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Pomodoro"
BUNDLE="$APP_NAME.app"

swift build -c release

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp ".build/release/$APP_NAME" "$BUNDLE/Contents/MacOS/$APP_NAME"
cp Info.plist "$BUNDLE/Contents/Info.plist"

# config.json ships inside a SwiftPM resource bundle; Bundle.module finds it
# in Contents/Resources at runtime.
cp -R ".build/release/${APP_NAME}_${APP_NAME}.bundle" "$BUNDLE/Contents/Resources/"

if [ -f Resources/AppIcon.icns ]; then
    cp Resources/AppIcon.icns "$BUNDLE/Contents/Resources/AppIcon.icns"
fi

swift Scripts/apply-config.swift app.json "$BUNDLE/Contents/Info.plist"
codesign --force --deep --sign - "$BUNDLE"

echo "Built $BUNDLE — run with: open $BUNDLE"
