import AppKit
import PomodoroCore

@MainActor
final class SoundPlayer {
    static let names = [
        "None", "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
        "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink",
    ]

    var settings: SoundSettings

    init(settings: SoundSettings) {
        self.settings = settings
    }

    func play(afterFinishing phase: Phase) {
        guard settings.soundEnabled else { return }
        play(named: settings.sound(afterFinishing: phase))
    }

    func play(named name: String) {
        guard name != "None", let sound = NSSound(named: name) else { return }
        sound.volume = Float(settings.volume)
        sound.play()
    }
}
