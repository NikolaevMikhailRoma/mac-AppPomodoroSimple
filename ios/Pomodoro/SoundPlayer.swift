import AVFoundation
import UserNotifications

/// The iPhone's own alert tones. The Mac's sounds are macOS's and do not
/// exist here, so a name from there (or one this iOS lacks) means the first tone.
@MainActor
final class SoundPlayer {
    struct Sound: Hashable {
        let key: String
        var title: String { key.replacingOccurrences(of: "_", with: " ") }
    }

    private static let folder: URL = {
        // The simulator keeps iOS's files inside its runtime, not at /System.
        let root = ProcessInfo.processInfo.environment["SIMULATOR_ROOT"] ?? ""
        return URL(fileURLWithPath: root + "/System/Library/Audio/UISounds/New")
    }()

    let available: [Sound] = ((try? FileManager.default.contentsOfDirectory(atPath: SoundPlayer.folder.path)) ?? [])
        .filter { $0.hasSuffix(".caf") }
        .map { Sound(key: String($0.dropLast(4))) }
        .sorted { $0.key < $1.key }

    private var player: AVAudioPlayer?

    init() {
        // Ambient: the silent switch silences it, and the user's music keeps playing.
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
    }

    func resolve(_ key: String) -> Sound? {
        available.first { $0.key == key } ?? available.first
    }

    func play(_ key: String, volume: Double) {
        guard let sound = resolve(key),
              let player = try? AVAudioPlayer(contentsOf: Self.file(sound)) else { return }
        player.volume = Float(volume)
        player.play()
        self.player = player
    }

    /// Notifications play only the app's own files: the tone is copied into
    /// Library/Sounds first. They play at the phone's volume, not the slider's.
    func notificationSound(_ key: String) -> UNNotificationSound {
        guard let sound = resolve(key) else { return .default }
        let files = FileManager.default
        let folder = files.urls(for: .libraryDirectory, in: .userDomainMask)[0].appendingPathComponent("Sounds")
        let copy = folder.appendingPathComponent(Self.file(sound).lastPathComponent)
        if !files.fileExists(atPath: copy.path) {
            try? files.createDirectory(at: folder, withIntermediateDirectories: true)
            guard (try? files.copyItem(at: Self.file(sound), to: copy)) != nil else { return .default }
        }
        return UNNotificationSound(named: UNNotificationSoundName(copy.lastPathComponent))
    }

    private static func file(_ sound: Sound) -> URL {
        folder.appendingPathComponent(sound.key + ".caf")
    }
}
