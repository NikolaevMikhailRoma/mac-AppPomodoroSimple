# Debug information

## Size (0.3.1)

| | Installer file | On disk, installed | Memory (RAM), running |
|---|---|---|---|
| Mac | 0.73 MB (`Pomodoro.app.zip`) | 1.4 MB | 11–13 MB |
| Android | 1.8 MB (`Pomodoro.apk`) | 5.3 MB: app 4.8, data and cache 0.5 | 22 MB |
| iPhone | — (built from source) | 1.2 MB, plus 0.4 MB per notification tone | 21 MB |

- Disk is taken all the time; memory only while the app runs.
- Android keeps the `.apk` and, next to it, its code unpacked (`base.vdex`, 2.9 MB).
- The phones' memory was measured on the emulator and the simulator. On the Mac a
  running interval takes 0.4 s of processor time a minute; an idle app, none.
- Measured with `du -sk`, `footprint <pid>` (`phys_footprint`) and
  `adb shell dumpsys meminfo com.nikolaev.pomodoro` (`TOTAL PSS`).

## Where the data is

The timer state holds the counters: `completedToday` (Today) and `sinceLongBreak`.

### Mac

| What | Where |
|---|---|
| Settings, paired phones | `~/Library/Preferences/com.nikolaev.pomodoro.plist`: `Settings`, `SyncDevices`, `SyncMacId` |
| Phones' keys | login Keychain: service `com.nikolaev.pomodoro.sync`, account = the phone's id |
| Timer and counters | memory only: a restart starts from zero, unless a paired phone sends its state |

`defaults read com.nikolaev.pomodoro`. A debug build (`.build/debug/Pomodoro`) keeps
its own settings under `Pomodoro`; `--pair` prints the pairing link.

### iPhone

| What | Where |
|---|---|
| Settings, timer, pairing | the app's `Library/Preferences/com.nikolaev.pomodoro.plist`: `Settings`, `EngineState`, `ShowOnLockScreen`, `PhoneId`, `MacId`, `MacName`, `MacKind`, `MacHost`, `MacPort` |
| The Mac's key | Keychain: service `com.nikolaev.pomodoro.sync`, account `deviceKey`, this iPhone only |
| Notification tones | `Library/Sounds/` |

Simulator: `xcrun simctl get_app_container booted com.nikolaev.pomodoro data`.

### Android

| What | Where |
|---|---|
| Settings, timer | `shared_prefs/pomodoro.xml`: `settings`, `engineState`, `askedNotifications` |
| Pairing | `shared_prefs/sync.xml`: `phoneId`, `macId`, `macName`, `macKind`, `host`, `port`, `deviceKey` |
| The Mac's key | `deviceKey`, encrypted with the Android Keystore key `pomodoro-sync`, which never leaves the phone |

Logs: `adb logcat -s PomodoroSync`. Auto Backup is on, so these files can go into the
phone's Google backup; the Mac's key there is useless without the phone's Keystore key.

The sync protocol: [SYNC.md](SYNC.md).
