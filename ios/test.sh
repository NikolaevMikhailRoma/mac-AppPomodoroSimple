#!/bin/bash
# Click through every screen on a fresh install in the simulator and save a
# screenshot of each into the given folder.
#   ./test.sh /tmp/shots
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
SHOTS="${1:?usage: test.sh <screenshot folder>}"
SIM="${SIM:-iPhone 12 mini}"
BUILD="$HOME/Library/Developer/Xcode/DerivedData/PomodoroPhone"

mkdir -p "$SHOTS"
xcodegen generate --spec "$DIR/project.yml" --quiet
xcrun simctl boot "$SIM" 2>/dev/null || true
XCODEBUILD=(xcodebuild -project "$DIR/Pomodoro.xcodeproj" -scheme PomodoroPhone
    -destination "platform=iOS Simulator,arch=arm64,name=$SIM" -derivedDataPath "$BUILD" MARKETING_VERSION=0.0.0)
"${XCODEBUILD[@]}" -quiet build-for-testing
# A fresh install: no saved timer, no permissions given yet. Installed and
# started once before the test: right after an install the simulator takes
# its time to draw the Live Activity, longer than any test should wait.
xcrun simctl uninstall "$SIM" com.nikolaev.pomodoro
xcrun simctl install "$SIM" "$BUILD/Build/Products/Debug-iphonesimulator/Pomodoro.app"
xcrun simctl launch "$SIM" com.nikolaev.pomodoro >/dev/null
sleep 5
xcrun simctl terminate "$SIM" com.nikolaev.pomodoro
# TEST_RUNNER_ variables reach the test process without the prefix.
TEST_RUNNER_SHOTS="$SHOTS" "${XCODEBUILD[@]}" test-without-building 2>&1 \
    | grep -E "error:|Test Case|TEST (SUCCEEDED|FAILED)"
