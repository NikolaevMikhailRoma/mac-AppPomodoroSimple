#!/bin/bash
# Build, install and (re)start the app on the connected device or emulator.
#   ./run.sh           debug build: fast to build, 30 MB, `adb shell run-as` works
#   ./run.sh release   what goes on the phone: shrunk by R8 to about 2 MB
# With several devices attached, pick one: ANDROID_SERIAL=emulator-5554 ./run.sh
# Both builds are signed with the same key, so either installs over the other.
set -euo pipefail
. ~/AndroidDev/env.sh
DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGE="com.nikolaev.pomodoro"
VARIANT="${1:-debug}"
case "$VARIANT" in
    debug) TASK=assembleDebug ;;
    release) TASK=assembleRelease ;;
    *) echo "usage: run.sh [debug|release]" >&2; exit 1 ;;
esac

"$DIR/gradlew" -p "$DIR" "$TASK" testDebugUnitTest --console=plain -q
adb install -r "$DIR/app/build/outputs/apk/$VARIANT/app-$VARIANT.apk" >/dev/null
# -S force-stops the running copy first, so the new build is what you see.
adb shell am start -S -W -n "$PACKAGE/.MainActivity" | grep -E 'Status|TotalTime'
echo "running $VARIANT, pid $(adb shell pidof "$PACKAGE") on $(adb get-serialno)"
