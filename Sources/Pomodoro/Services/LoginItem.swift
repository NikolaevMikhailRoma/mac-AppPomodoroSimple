import AppKit
import Observation
import ServiceManagement

/// «Открывать при входе». Состояние не хранится у нас, а каждый раз читается у
/// системы: пользователь может выключить приложение в Системных настройках, и
/// галочка должна это показать.
@MainActor
@Observable
final class LoginItem {
    private(set) var isEnabled = false
    /// Автозапуск выключен в Системных настройках → Объекты входа. Включить его
    /// обратно из приложения система не даёт — только оттуда.
    private(set) var isBlockedBySystem = false

    @ObservationIgnored private var activationObserver: NSObjectProtocol?

    init() {
        refresh()
        // Возвращаясь из Системных настроек, пользователь снова активирует нас.
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled
        isBlockedBySystem = status == .requiresApproval
    }

    func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Причину показывает сама галочка: после refresh() она встанет так,
            // как решила система, а при блокировке появится подсказка.
        }
        refresh()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
