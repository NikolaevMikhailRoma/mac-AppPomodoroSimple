import PomodoroConfig
import SwiftUI

/// The look, from the Mac's config.json: the same colours and fonts.
/// Helvetica Neue ships with iOS too, so the digits are the Mac's.
@MainActor
enum Theme {
    /// Controls in settings take the work colour, as on Android.
    static let accent = Color(hex: Shared.config.ring.workColor)

    // The settings screen, in phone points rather than the Mac window's.
    static let background = Color(hex: Shared.config.settingsWindow.background)
    static let box = Color(hex: Shared.config.settingsWindow.boxBackground)
    static let border = Color(hex: Shared.config.settingsWindow.boxBorder)
    static let label = Color(hex: Shared.config.settingsWindow.labelColor)
    static let secondary = Color(hex: Shared.config.settingsWindow.sectionHeaderColor)
    static let labelFont = Font.system(size: 16)
    static let secondaryFont = Font.system(size: 13)

    static func font(_ token: FontToken, scale: Double = 1) -> Font {
        .custom(token.name, fixedSize: token.size * scale)
    }

    static func icon(_ icon: IconConfig, scale: Double, color: Color) -> some View {
        Image(systemName: icon.symbol)
            .font(.system(size: icon.size * scale, weight: weight(icon.weight)))
            .foregroundStyle(color)
    }

    private static func weight(_ name: String) -> Font.Weight {
        switch name.lowercased() {
        case "ultralight": return .ultraLight
        case "thin": return .thin
        case "light": return .light
        case "medium": return .medium
        case "semibold": return .semibold
        case "bold": return .bold
        default: return .regular
        }
    }
}

/// A hint that appears and fades out on its own. To show it, raise `trigger`;
/// it always holds its space, so neighbours never jump.
struct TransientHint: View {
    let text: String
    let trigger: Int

    @State private var visible = false

    var body: some View {
        Text(text)
            .fixedSize()
            .opacity(visible ? 1 : 0)
            .allowsHitTesting(false)
            .task(id: trigger) {
                guard trigger > 0 else { return }
                withAnimation(.easeOut(duration: 0.15)) { visible = true }
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                withAnimation(.easeIn(duration: 0.4)) { visible = false }
            }
    }
}
