import AppKit
import SwiftUI
import PomodoroCore

enum Theme {
    static func color(_ hex: String, fallback: NSColor = .labelColor) -> NSColor {
        var text = hex.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6 || text.count == 8,
              let value = UInt64(text, radix: 16) else { return fallback }

        let hasAlpha = text.count == 8
        let r = Double((value >> (hasAlpha ? 24 : 16)) & 0xFF) / 255
        let g = Double((value >> (hasAlpha ? 16 : 8)) & 0xFF) / 255
        let b = Double((value >> (hasAlpha ? 8 : 0)) & 0xFF) / 255
        let a = hasAlpha ? Double(value & 0xFF) / 255 : 1
        return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
    }

    static func swiftUIColor(_ hex: String, fallback: NSColor = .labelColor) -> Color {
        Color(nsColor: color(hex, fallback: fallback))
    }

    static func font(_ token: FontToken) -> Font {
        guard let nsFont = NSFont(name: token.name, size: token.size) else {
            return .system(size: token.size, weight: .thin)
        }
        return Font(nsFont)
    }

    @MainActor
    static func applyAppearance(_ appearance: Appearance) {
        switch appearance {
        case .auto: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

extension AppConfig {
    static func load() -> AppConfig {
        guard let url = Bundle.module.url(forResource: "config", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return AppConfig() }
        return AppConfig.decode(data)
    }
}
