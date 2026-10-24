#!/bin/bash
# Generate the project, build, install and (re)start the app on the iPhone,
# over Wi-Fi. Signed with the Apple Account added in Xcode → Settings → Accounts;
# its certificate names the team.
#   DEVICE=<udid> ./device.sh   another device than the first one paired
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
BUNDLE="com.nikolaev.pomodoro"
VERSION="$(plutil -extract version raw "$DIR/../app.json")"
# Outside Dropbox: it marks app bundles inside it, and codesign refuses them.
BUILD="$HOME/Library/Developer/Xcode/DerivedData/PomodoroPhone"

if [ -z "${DEVICE:-}" ]; then
    LIST="$(mktemp)"
    xcrun devicectl list devices --quiet --filter "hardwareProperties.platform == 'iOS'" --json-output "$LIST" >/dev/null
    DEVICE="$(plutil -extract result.devices.0.hardwareProperties.udid raw "$LIST" 2>/dev/null || true)"
    rm -f "$LIST"
fi
[ -n "$DEVICE" ] || { echo "No iPhone paired with this Mac." >&2; exit 1; }
TEAM="$(security find-certificate -c "Apple Development" -p 2>/dev/null \
    | openssl x509 -noout -subject -nameopt multiline 2>/dev/null \
    | awk -F' = ' '/organizationalUnitName/ { print $2; exit }')"
[ -n "$TEAM" ] || { echo "No Apple Development certificate: Xcode → Settings → Accounts → Manage Certificates…" >&2; exit 1; }

xcodegen generate --spec "$DIR/project.yml" --quiet
xcodebuild -project "$DIR/Pomodoro.xcodeproj" -scheme PomodoroPhone -configuration Release \
    -destination "id=$DEVICE" -derivedDataPath "$BUILD" -allowProvisioningUpdates \
    DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_STYLE=Automatic MARKETING_VERSION="$VERSION" -quiet build
xcrun devicectl device install app --device "$DEVICE" "$BUILD/Build/Products/Release-iphoneos/Pomodoro.app"
xcrun devicectl device process launch --terminate-existing --device "$DEVICE" "$BUNDLE"
