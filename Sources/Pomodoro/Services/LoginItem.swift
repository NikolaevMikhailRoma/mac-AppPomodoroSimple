import ServiceManagement

/// Регистрация в «Открывать при входе». Возвращает состояние, которое система
/// подтвердила: запрос может быть отклонён, и тогда галочка не должна встать.
enum LoginItem {
    @MainActor
    static func set(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return enabled
        } catch {
            return SMAppService.mainApp.status == .enabled
        }
    }
}
