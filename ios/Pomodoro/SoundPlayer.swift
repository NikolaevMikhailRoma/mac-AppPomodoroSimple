import AVFoundation
import PomodoroCore
import UserNotifications

/// The iPhone's own alert tones. The Mac's sounds are macOS's and do not
/// exist here; the timer swaps a name it lacks for one of these.
@MainActor
final class SoundPlayer: SoundOutput {
    private static let folder: URL = {
        // The simulator keeps iOS's files inside its runtime, not at /System.
        let root = ProcessInfo.processInfo.environment["SIMULATOR_ROOT"] ?? ""
        return URL(fileURLWithPath: root + "/System/Library/Audio/UISounds/New")
    }()

    let names: [String] = ((try? FileManager.default.contentsOfDirectory(atPath: SoundPlayer.folder.path)) ?? [])
        .filter { $0.hasSuffix(".caf") }
        .map { String($0.dropLast(4)) }
        .sorted()

    private var player: AVAudioPlayer?

    init() {
        // Ambient: the silent switch silences it, and the user's music keeps playing.
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
    }

    static func title(_ name: String) -> String {
        name.replacingOccurrences(of: "_", with: " ")
    }

    func play(_ name: String, volume: Double) {
        guard let player = try? AVAudioPlayer(contentsOf: Self.file(name)) else { return }
        player.volume = Float(volume)
        player.play()
        self.player = player
    }

    /// Notifications play only the app's own files: the tone is copied into
    /// Library/Sounds first. They play at the phone's volume, not the slider's.
    func notificationSound(_ name: String) -> UNNotificationSound {
        let files = FileManager.default
        let folder = files.urls(for: .libraryDirectory, in: .userDomainMask)[0].appendingPathComponent("Sounds")
        let copy = folder.appendingPathComponent(Self.file(name).lastPathComponent)
        if !files.fileExists(atPath: copy.path) {
            try? files.createDirectory(at: folder, withIntermediateDirectories: true)
            guard (try? files.copyItem(at: Self.file(name), to: copy)) != nil else { return .default }
        }
        return UNNotificationSound(named: UNNotificationSoundName(copy.lastPathComponent))
    }

    private static func file(_ name: String) -> URL {
        folder.appendingPathComponent(name + ".caf")
    }
}
