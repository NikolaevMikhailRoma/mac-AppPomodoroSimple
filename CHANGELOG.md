# Changelog

## 0.1.2 — unreleased

- Fixed: the app crashed on launch on any Mac other than the one it was built on. `config.json` is now looked up in `Contents/Resources` of the app instead of through `Bundle.module`.

## 0.1.1

- Fixed: a second copy of the app no longer starts next to the running one.
- Skip button counts the skipped work interval.
- Durations are capped at 59:59, with a hint when the typed value is over it.
- The ring handle stops at 12 o'clock instead of wrapping around.

## 0.1.0

First release.
