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
        if let file = path(for: "--snapshot-settings") {
            let tab = path(for: "--tab").flatMap(SettingsTab.init(name:)) ?? .general
            return renderSettingsWindow(tab: tab, to: file)
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
              let rep = NSBitmapImageRep(data: tiff) else {
            fail("could not render")
        }
        write(rep, to: path)
        return true
    }

    private static func renderSettingsWindow(tab: SettingsTab, to path: String) -> Bool {
        let config = AppConfig.load()
        let defaults = UserDefaults(suiteName: "PomodoroSnapshot")!
        defaults.removePersistentDomain(forName: "PomodoroSnapshot")
        let controller = SettingsWindowController(
            store: SettingsStore(defaults: defaults, fallback: Settings(intervals: config.intervals)),
            loginItem: LoginItem(),
            config: config,
            tab: tab
        )

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        controller.show()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            controller.window.makeFirstResponder(nil)
            guard let view = controller.window.contentView?.superview,
                  let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                fail("could not render the settings window")
            }
            view.cacheDisplay(in: view.bounds, to: rep)
            write(rep, to: path)
            exit(0)
        }
        app.run()
        return true
    }

    private static func write(_ rep: NSBitmapImageRep, to path: String) {
        guard let png = rep.representation(using: .png, properties: [:]) else {
            fail("could not encode PNG")
        }
        do {
            try png.write(to: URL(fileURLWithPath: path))
            print("Wrote \(path)")
        } catch {
            fail("\(error)")
        }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("snapshot: \(message)\n".utf8))
        exit(1)
    }
}
