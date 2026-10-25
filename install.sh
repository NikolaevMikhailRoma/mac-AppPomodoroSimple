#!/bin/bash
# Build an app and put it on a device named on the command line. Without a
# name the script lists the devices it sees and installs nothing.
#   ./install.sh mac                this Mac: quits Pomodoro, rebuilds Pomodoro.app here, starts it
#   ./install.sh android <name>     a phone adb sees (Wireless debugging connected), by part of its model or serial
#   ./install.sh ios <name>         an iPhone paired with this Mac, by part of its name
set -euo pipefail
cd "$(dirname "$0")"
PACKAGE="$(plutil -extract bundleIdentifier raw app.json)"
NAME="${2:-}"

# Pick the one line of "$1" (a device per line) that mentions $NAME, or list them all and stop.
pick() {
    local found
    found="$(grep -i -F -- "$NAME" <<< "$1" || true)"
    if [ -z "$NAME" ] || [ "$(grep -c . <<< "$found")" -ne 1 ]; then
        if [ -z "$NAME" ]; then echo "Name a device:" >&2; else echo "Not exactly one device matches \"$NAME\":" >&2; fi
        echo "${1:-  (none)}" >&2
        exit 1
    fi
    echo "$found"
}

case "${1:-}" in
mac)
    pkill -x Pomodoro || true
    ./build.sh mac
    open Pomodoro.app
    ;;
android)
    if [ -f ~/AndroidDev/env.sh ]; then . ~/AndroidDev/env.sh; fi
    # "<serial>  <model>" for every device that is ready.
    devices="$(adb devices -l | awk 'NR > 1 && $2 == "device" { model = ""; for (i = 3; i <= NF; i++) if ($i ~ /^model:/) model = substr($i, 7); print "  " $1 "  " model }')"
    serial="$(pick "$devices" | awk '{ print $1 }')"
    ./build.sh android
    adb -s "$serial" install -r Pomodoro.apk
    adb -s "$serial" shell am start -S -n "$PACKAGE/.MainActivity" >/dev/null
    echo "Installed and started on $serial"
    ;;
ios)
    list="$(mktemp)"
    xcrun devicectl list devices --quiet --filter "hardwareProperties.platform == 'iOS'" --json-output "$list" >/dev/null
    # "<udid>  <name>  <model>" for every paired iPhone.
    devices="$(for ((i = 0; i < $(plutil -extract result.devices raw "$list"); i++)); do
        echo "  $(plutil -extract result.devices.$i.hardwareProperties.udid raw "$list")  $(plutil -extract result.devices.$i.deviceProperties.name raw "$list")  ($(plutil -extract result.devices.$i.hardwareProperties.marketingName raw "$list"))"
    done)"
    rm -f "$list"
    udid="$(pick "$devices" | awk '{ print $1 }')"
    ./build.sh ios
    xcrun devicectl device install app --device "$udid" "$HOME/Library/Developer/Xcode/DerivedData/PomodoroPhone/Build/Products/Release-iphoneos/Pomodoro.app"
    xcrun devicectl device process launch --terminate-existing --device "$udid" "$PACKAGE"
    ;;
*)
    echo "usage: install.sh mac | android <name> | ios <name>" >&2
    exit 1
    ;;
esac
