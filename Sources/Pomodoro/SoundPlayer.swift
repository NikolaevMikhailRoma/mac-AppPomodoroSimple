import AppKit
import PomodoroCore

/// Plays a macOS system sound when a phase ends.
///
/// System sounds are used rather than bundled audio files: nothing to ship, and
/// the names in the settings popup are the ones the user already knows.
@MainActor
final class SoundPlayer {

    /// What the Settings popup offers. `none` is first so silence is one click.
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

    /// Also used by the Settings window to preview a choice.
    func play(named name: String) {
        guard name != "None", let sound = NSSound(named: name) else { return }
        sound.volume = Float(settings.volume)
        sound.play()
    }
}
