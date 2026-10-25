import AppKit
import SwiftUI
import PomodoroCore
import PomodoroConfig

enum Theme {
    static func color(_ hex: String, fallback: NSColor = .labelColor) -> NSColor {
        guard let c = RGBA(hex: hex) else { return fallback }
        return NSColor(srgbRed: c.red, green: c.green, blue: c.blue, alpha: c.alpha)
    }

    /// A weight name from the config as an NSFont.Weight. One table for fonts
    /// and icons alike — SF Symbols take a weight of the same type.
    static func weight(named name: String) -> NSFont.Weight {
        switch name.lowercased() {
        case "ultralight": return .ultraLight
        case "thin": return .thin
        case "light": return .light
        case "regular": return .regular
        case "medium": return .medium
        case "semibold": return .semibold
        case "bold": return .bold
        default: return .regular
        }
    }

    /// The same icon for AppKit: the menu bar draws an NSImage, not a View.
    /// `isTemplate = false` is required, or the system recolours the symbol
    /// itself and the palette colour is ignored.
    static func image(_ icon: IconConfig, color: NSColor) -> NSImage? {
        let image = NSImage(systemSymbolName: icon.symbol, accessibilityDescription: "Pomodoro")
        image?.isTemplate = false
        return image?.withSymbolConfiguration(
            NSImage.SymbolConfiguration(pointSize: icon.size, weight: weight(named: icon.weight))
                .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        )
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
