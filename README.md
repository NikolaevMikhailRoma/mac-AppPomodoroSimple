# Pomodoro

![macOS 15+](https://img.shields.io/badge/macOS-15%2B-black?logo=apple)
![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)
![Android 8+](https://img.shields.io/badge/Android-8%2B-3DDC84?logo=android&logoColor=white)
![Kotlin 2.4](https://img.shields.io/badge/Kotlin-2.4-7F52FF?logo=kotlin&logoColor=white)
[![License](https://img.shields.io/github/license/NikolaevMikhailRoma/mac-AppPomodoroSimple)](LICENSE)
[![Release](https://img.shields.io/github/v/release/NikolaevMikhailRoma/mac-AppPomodoroSimple)](https://github.com/NikolaevMikhailRoma/mac-AppPomodoroSimple/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/NikolaevMikhailRoma/mac-AppPomodoroSimple/total)](https://github.com/NikolaevMikhailRoma/mac-AppPomodoroSimple/releases)

# (experimental)
- added android app
- linked mac and android app, by local network and keychain

# macOS
![Menu bar and timer](assets/popover.png)

A minimal native macOS menu bar pomodoro timer: red while working, green on a
break, grey when stopped. No Dock icon, no main window. Drag the ring to set the
interval (up to 59:59) or click the digits to type it. The ▷| button finishes
work early and counts it — handy when you forgot to start the timer — or skips a
break. Right-click the menu bar icon for the same action, Settings and Quit.

Settings: intervals, the sound and notification at the end of an interval,
launch at startup, and a light/dark/auto appearance.

<p>
  <img src="assets/settings-general.png" width="270" alt="General">
  <img src="assets/settings-intervals.png" width="270" alt="Intervals">
  <img src="assets/settings-sounds.png" width="270" alt="Notifications & Sounds">
</p>

## Run the app (users)

1. Download `Pomodoro.app.zip` from the [latest release](https://github.com/NikolaevMikhailRoma/mac-AppPomodoroSimple/releases/latest) and unzip it.
2. Move it wherever you like (e.g. Applications).
3. First launch: right-click the app → **Open** (it's ad-hoc signed, not notarized by Apple, so Gatekeeper shows one warning before the app even starts — this is expected, click Open to proceed).
4. Once the app launches, macOS will separately ask to allow notifications — allow it if you want the alert when an interval ends. Look for the timer in the menu bar; there is no window.

## Build from source (developers)

All the source is in this repo and safe to review — no third-party dependencies, only Apple's own frameworks.

Requirements:
- macOS 15+
- Xcode Command Line Tools (provides `swift`, `iconutil`, `codesign`) — install with `xcode-select --install` if `swift --version` doesn't work yet

```
git clone https://github.com/NikolaevMikhailRoma/mac-AppPomodoroSimple.git
cd mac-AppPomodoroSimple
./build.sh
open Pomodoro.app
```

Run the unit tests with `swift test` (pure logic lives in the `PomodoroCore` and
`PomodoroConfig` targets). Every colour, size and icon is in
[`config.json`](Sources/PomodoroConfig/Resources/config.json), not in the code.

# Android (experimental)

The same timer on Android 8 and newer. Tested on a Motorola Edge 50 with Android 16.

<p>
  <img src="assets/android-timer.png" width="270" alt="Android timer">
  <img src="assets/android-settings.png" width="270" alt="Android settings">
</p>

## Run the app (users)

1. Download `Pomodoro.apk` from the [latest release](https://github.com/NikolaevMikhailRoma/mac-AppPomodoroSimple/releases/latest) on the phone and open it.
2. Allow installing from that app (Files, the browser) when Android asks. Google Play Protect may warn about an unknown app: choose **Install anyway**.

## Build from source (developers)

To build it yourself: JDK 21 and the Android SDK, then `cd android && ./gradlew assembleRelease`.

# Version history

What changed in each version: [CHANGELOG.md](CHANGELOG.md).

- **0.2.0** — experimental Android app; the Mac app is unchanged.
- **0.1.2** — fixed a crash on launch on another Mac.
- **0.1.1** — ▷| counts a skipped work interval, 59:59 limit with hints, a second copy no longer starts.
- **0.1.0** — first release: menu bar timer, ring, settings, sounds and notifications.

# License

MIT — use it however you like.
