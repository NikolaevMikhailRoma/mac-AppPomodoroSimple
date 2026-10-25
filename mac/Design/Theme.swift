import AppKit
import SwiftUI
import PomodoroCore
import PomodoroConfig

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

    /// The same for SwiftUI, which has a weight type of its own. The two tables
    /// must agree, or one config key gives different weights in the menu bar and
    /// in the popover.
    static func fontWeight(named name: String) -> Font.Weight {
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

    /// An icon for SwiftUI. Size and weight come from the config; the colour is
    /// set by the caller, because it follows the phase, not the icon.
    static func icon(_ icon: IconConfig, color: Color) -> some View {
        Image(systemName: icon.symbol)
            .font(.system(size: icon.size, weight: fontWeight(named: icon.weight)))
            .foregroundStyle(color)
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
