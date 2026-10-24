#!/bin/bash
# Generate the project, build, install and (re)start the app on the simulator.
#   SIM="iPhone 15" ./run.sh   another simulator than the 12 mini
#   ./run.sh -pairLink '<link>' arguments after the options go to the app
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
BUNDLE="com.nikolaev.pomodoro"
SIM="${SIM:-iPhone 12 mini}"
VERSION="$(plutil -extract version raw "$DIR/../app.json")"
# Outside Dropbox: it marks app bundles inside it, and codesign refuses them.
BUILD="$HOME/Library/Developer/Xcode/DerivedData/PomodoroPhone"

xcodegen generate --spec "$DIR/project.yml" --quiet
xcodebuild -project "$DIR/Pomodoro.xcodeproj" -scheme PomodoroPhone \
    -destination "platform=iOS Simulator,arch=arm64,name=$SIM" -derivedDataPath "$BUILD" \
    MARKETING_VERSION="$VERSION" -quiet build
xcrun simctl boot "$SIM" 2>/dev/null || true
open -a Simulator
xcrun simctl install "$SIM" "$BUILD/Build/Products/Debug-iphonesimulator/Pomodoro.app"
# --terminate-running-process: the new build is what you see.
xcrun simctl launch --terminate-running-process "$SIM" "$BUNDLE" "$@"
