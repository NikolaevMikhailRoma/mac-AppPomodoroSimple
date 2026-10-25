#!/bin/bash
# Build the apps, one after another, or only the one named:
#   ./build.sh                  all three
#   ./build.sh mac              Pomodoro.app, here
#   ./build.sh android          Pomodoro.apk, here
#   ./build.sh ios              in Xcode's DerivedData; install.sh puts it on the iPhone
set -euo pipefail
cd "$(dirname "$0")"
VERSION="$(plutil -extract version raw app.json)"
# Outside Dropbox: it marks app bundles inside it, and codesign refuses them.
IOS_BUILD="$HOME/Library/Developer/Xcode/DerivedData/PomodoroPhone"
IOS_APP="$IOS_BUILD/Build/Products/Release-iphoneos/Pomodoro.app"

build_mac() {
    swift build -c release
    rm -rf Pomodoro.app
    mkdir -p Pomodoro.app/Contents/MacOS Pomodoro.app/Contents/Resources
    cp .build/release/Pomodoro Pomodoro.app/Contents/MacOS/Pomodoro
    # The symbols are almost half the binary, and nothing reads them on a user's Mac.
    strip -x Pomodoro.app/Contents/MacOS/Pomodoro
    cp mac/Info.plist Pomodoro.app/Contents/Info.plist
    # config.json ships inside the PomodoroConfig resource bundle; AppConfig.load finds it
    # in Contents/Resources at runtime.
    cp -R .build/release/Pomodoro_PomodoroConfig.bundle Pomodoro.app/Contents/Resources/
    cp mac/Resources/AppIcon.icns Pomodoro.app/Contents/Resources/AppIcon.icns
    swift scripts/apply-config.swift app.json Pomodoro.app/Contents/Info.plist
    codesign --force --deep --sign - Pomodoro.app
    echo "Built Pomodoro.app — run with: open Pomodoro.app"
}

build_android() {
    # The JDK and the SDK: ~/AndroidDev if it is there, otherwise JAVA_HOME and ANDROID_HOME.
    if [ -f ~/AndroidDev/env.sh ]; then . ~/AndroidDev/env.sh; fi
    android/gradlew -p android assembleRelease --console=plain -q
    cp android/app/build/outputs/apk/release/app-release.apk Pomodoro.apk
    echo "Built Pomodoro.apk"
}

build_ios() {
    # Signed with the Apple Account added in Xcode → Settings → Accounts; its certificate names the team.
    local team
    team="$(security find-certificate -c "Apple Development" -p 2>/dev/null \
        | openssl x509 -noout -subject -nameopt multiline 2>/dev/null \
        | awk -F' = ' '/organizationalUnitName/ { print $2; exit }')"
    [ -n "$team" ] || { echo "No Apple Development certificate: Xcode → Settings → Accounts → Manage Certificates…" >&2; exit 1; }
    xcodegen generate --spec ios/project.yml --quiet
    xcodebuild -project ios/Pomodoro.xcodeproj -scheme PomodoroPhone -configuration Release \
        -destination generic/platform=iOS -derivedDataPath "$IOS_BUILD" -allowProvisioningUpdates \
        DEVELOPMENT_TEAM="$team" CODE_SIGN_STYLE=Automatic MARKETING_VERSION="$VERSION" -quiet build
    echo "Built $IOS_APP"
}

case "${1:-all}" in
    mac) build_mac ;;
    android) build_android ;;
    ios) build_ios ;;
    all) build_mac; build_android; build_ios ;;
    *) echo "usage: build.sh [mac|android|ios]" >&2; exit 1 ;;
esac
