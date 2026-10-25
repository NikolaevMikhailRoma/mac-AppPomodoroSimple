import PomodoroConfig
import SwiftUI

extension AppConfig {
    #if os(iOS)
    static let onPhone = true
    #else
    static let onPhone = false
    #endif

    /// The settings window's sizes on this screen: the Mac's own, or larger for a finger.
    public var settingsMetrics: SettingsWindowConfig {
        Self.onPhone ? settingsWindow.forPhone(phone) : settingsWindow
    }

    /// The smallest touch area of a button: none on the Mac, where a pointer is precise.
    var minTouch: Double { Self.onPhone ? phone.minTouch : 0 }

    /// The band along the ring that takes a touch; nil takes the whole disc.
    var ringTouchBand: Double? { Self.onPhone ? phone.ringTouchBand : nil }
}

extension Color {
    /// "#RRGGBB" or "#RRGGBBAA"; anything else is white.
    public init(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6 || text.count == 8, let value = UInt64(text, radix: 16) else {
            self = .white
            return
        }
        let alpha = text.count == 8
        let channel = { (shift: UInt64) in Double((value >> shift) & 0xFF) / 255 }
        self.init(
            .sRGB,
            red: channel(alpha ? 24 : 16),
            green: channel(alpha ? 16 : 8),
            blue: channel(alpha ? 8 : 0),
            opacity: alpha ? channel(0) : 1
        )
    }
}

extension FontToken {
    func font(scale: Double = 1) -> Font {
        .custom(name, fixedSize: size * scale)
    }
}

extension IconConfig {
    /// The symbol at the config's size and weight. The colour follows the
    /// phase, not the icon, so the caller gives it.
    func image(scale: Double = 1, color: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: size * scale, weight: Font.Weight(name: weight)))
            .foregroundStyle(color)
    }
}

extension Font.Weight {
    init(name: String) {
        switch name.lowercased() {
        case "ultralight": self = .ultraLight
        case "thin": self = .thin
        case "light": self = .light
        case "medium": self = .medium
        case "semibold": self = .semibold
        case "bold": self = .bold
        default: self = .regular
        }
    }
}

/// A hint that appears and fades out on its own, asking nothing of the user.
/// To show it, raise `trigger`; showing it again restarts the countdown. The
/// text always holds its space, so neighbours never jump, and touches pass
/// straight through it.
struct TransientHint: View {
    let text: String
    let trigger: Int

    private static let visibleSeconds = 2.0

    @State private var visible = false

    var body: some View {
        Text(text)
            .fixedSize(horizontal: true, vertical: true)
            .opacity(visible ? 1 : 0)
            .allowsHitTesting(false)
            .task(id: trigger) {
                guard trigger > 0 else { return }
                withAnimation(.easeOut(duration: 0.15)) { visible = true }
                try? await Task.sleep(for: .seconds(Self.visibleSeconds))
                guard !Task.isCancelled else { return }
                withAnimation(.easeIn(duration: 0.4)) { visible = false }
            }
    }
}
