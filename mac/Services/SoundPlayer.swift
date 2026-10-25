import AppKit
import PomodoroCore

/// macOS's own alert sounds.
@MainActor
final class SoundPlayer: SoundOutput {
    let names = [
        "None", "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
        "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink",
    ]

    func play(_ name: String, volume: Double) {
        guard name != "None", let sound = NSSound(named: name) else { return }
        sound.volume = Float(volume)
        sound.play()
    }
}
