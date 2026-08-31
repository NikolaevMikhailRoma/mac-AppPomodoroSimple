import AppKit
import SwiftUI
import PomodoroCore

/// Renders the popover to a PNG and exits, without opening a menu bar item.
///
/// A status item cannot be screenshotted from a terminal (the menu bar's icon
/// layer is not captured without Screen Recording permission), so this is the
/// only way to actually look at the popover while working on its layout.
///
///     swift run Pomodoro --snapshot /tmp/popover.png
///     swift run Pomodoro --snapshot-settings /tmp/settings.png
@MainActor
enum Snapshot {

    /// Consumes a snapshot flag if present. Returns true when it rendered,
    /// telling `main` to exit instead of launching the app.
    static func runIfRequested() -> Bool {
        let config = AppConfig.load()

        if let path = path(for: "--snapshot") {
            let timer = TimerController(config: config, settings: Settings())
            return render(TimerPopoverView(timer: timer, config: config, openSettings: {}), to: path)
        }
        if let path = path(for: "--snapshot-settings") {
            // A throwaway suite, so snapshotting never touches real settings.
            let defaults = UserDefaults(suiteName: "PomodoroSnapshot")!
            defaults.removePersistentDomain(forName: "PomodoroSnapshot")
            let store = SettingsStore(defaults: defaults)
            return render(SettingsView(store: store, config: config), to: path)
        }
        return false
    }

    private static func path(for flag: String) -> String? {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    private static func render(_ view: some View, to path: String) -> Bool {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2      // match the Retina reference screenshots

        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write(Data("snapshot: could not render\n".utf8))
            exit(1)
        }

        do {
            try png.write(to: URL(fileURLWithPath: path))
            print("Wrote \(path)")
        } catch {
            FileHandle.standardError.write(Data("snapshot: \(error)\n".utf8))
            exit(1)
        }
        return true
    }
}
