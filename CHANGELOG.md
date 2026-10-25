# Changelog

All notable changes, newest first. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.3.1] — 2026-10-25

### Changed
- The iPhone and Android settings look like the Mac's.
- Android uses the Inter font.
- Choosing a sound or letting go of the volume slider plays the sound on the Mac too, as on the phones.
- Smaller Mac and iPhone apps.
- The Mac app takes about a third less memory: the settings window is made when opened and let go when closed.
- The running timer ticks once a second instead of four times: on the Mac it takes a quarter of the processor time.
- The Android app is signed with its own key instead of the debug one.

### Added
- `./build.sh` and `./install.sh`.

## [0.3.0] — 2026-10-24

### Added
- iPhone version (experimental). Tested on an iPhone 12 mini.
- Sync between the Mac and the phones (experimental), over the one Wi-Fi; everything is encrypted.

## [0.2.0] — 2026-10-23

### Added
- Android version, for Android 8 and newer: design and settings the same.
- On Android the interval ends on time even when the app is closed or the phone is asleep, with a sound and a notification.
- On Android the running timer stays in the notification shade with a pause/resume button, and as an icon in the status bar.

The macOS app is unchanged apart from the version number.

## [0.1.2] — 2026-10-10

### Fixed
- The app no longer crashes on launch on a Mac other than the one it was built on.

## [0.1.1] — 2026-10-04

### Changed
- Skipping a work interval counts it.
- Durations are capped at 59:59, with a hint when the typed value is over the limit.
- The ring handle stops at 12 o'clock instead of wrapping around.

### Fixed
- A second copy of the app no longer starts next to the running one.

## [0.1.0] — 2026-08-31

### Added
- First release: menu bar timer with a popover ring, work and break intervals, settings window.

[0.3.1]: https://github.com/NikolaevMikhailRoma/mac-AppPomodoroSimple/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/NikolaevMikhailRoma/mac-AppPomodoroSimple/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/NikolaevMikhailRoma/mac-AppPomodoroSimple/compare/v0.1.2...v0.2.0
[0.1.2]: https://github.com/NikolaevMikhailRoma/mac-AppPomodoroSimple/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/NikolaevMikhailRoma/mac-AppPomodoroSimple/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/NikolaevMikhailRoma/mac-AppPomodoroSimple/releases/tag/v0.1.0
