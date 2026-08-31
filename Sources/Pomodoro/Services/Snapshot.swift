import AppKit
import SwiftUI
import PomodoroCore
import PomodoroConfig

@MainActor
enum Snapshot {
    private static let referenceScreenshotScale: CGFloat = 2

    static func runIfRequested() -> Bool {
        let config = AppConfig.load()

        if let path = path(for: "--snapshot") {
            let timer = TimerController(config: config, settings: Settings())
            return render(TimerPopoverView(timer: timer, config: config, openSettings: {}), to: path)
        }
        if let path = path(for: "--snapshot-settings") {
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
        renderer.scale = referenceScreenshotScale

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
