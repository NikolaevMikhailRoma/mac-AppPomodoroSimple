import SwiftUI

/// Подсказка, которая появляется и сама гаснет, ничего не требуя от
/// пользователя. Показать её — увеличить `trigger`; повторный показ
/// перезапускает отсчёт. Место под текст занято всегда, поэтому соседи не
/// прыгают, а нажатия проходят сквозь неё.
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
