import Foundation
import PomodoroCore

/// Форма `config.json`.
///
/// Дефолт каждого значения стоит прямо в объявлении поля — второго места, где
/// его нужно повторить, нет. Мягкость разбора обеспечивает `JSONValue.merged`:
/// пропущенный или кривой по типу ключ теряет только себя.
///
/// Добавить значение = поле здесь + строка в `Resources/config.json`.
public struct AppConfig: Codable, Equatable, Sendable {
    /// Именованные цвета. Любое поле-цвет в остальных секциях можно задать либо
    /// именем отсюда, либо литералом `#RRGGBB` — см. `JSONValue.resolvingPalette`.
    public var palette = Palette.defaults
    /// Все значки приложения. Это системные SF Symbols, файлов картинок нет.
    public var icons = IconsConfig()
    public var menuBar = MenuBarConfig()
    public var popover = PopoverConfig()
    public var ring = RingConfig()
    public var fonts = FontsConfig()
    public var settingsWindow = SettingsWindowConfig()
    public var dial = DialConfig()
    /// Длительности на первом запуске, пока пользователь не поменял их в настройках.
    public var intervals = IntervalSettings()

    public init() {}

    /// Разбирает файл, накладывая его на дефолты и раскрывая имена палитры.
    /// Файл не читается вовсе — возвращаются дефолты целиком.
    public static func decode(_ data: Data) -> AppConfig {
        let fallback = AppConfig()
        guard let baseData = try? JSONEncoder().encode(fallback),
              let base = try? JSONDecoder().decode(JSONValue.self, from: baseData),
              let user = try? JSONDecoder().decode(JSONValue.self, from: data),
              let resolved = try? JSONEncoder().encode(
                  JSONValue.resolvingPalette(JSONValue.merged(base, user))
              ),
              let config = try? JSONDecoder().decode(AppConfig.self, from: resolved)
        else { return fallback }
        return config
    }

    /// `config.json` лежит ресурсом этого таргета, поэтому `Bundle.module` — здешний.
    public static func load() -> AppConfig {
        guard let url = Bundle.module.url(forResource: "config", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return AppConfig() }
        return decode(data)
    }
}

/// Палитра — обычный словарь, поэтому новый цвет добавляется одной строкой в
/// JSON и не требует правки Swift. Дефолты здесь нужны, чтобы приложение имело
/// полный набор цветов даже без файла.
public enum Palette {
    public static let defaults: [String: String] = [
        // Цвет фазы. Значок в строке меню насыщенный, дуга кольца — светлее:
        // так в оригинале, это не производные друг от друга значения.
        "work": "#E62621",
        "workSoft": "#EC958C",
        "break": "#30A46C",
        "breakSoft": "#8CD3A2",
        // Таймер стоит.
        "idle": "#9B9B9B",
    ]
}

/// Значок: имя системного символа, кегль и вес. Одна структура на все три
/// применения — строка меню, шестерёнка, крестик.
public struct IconConfig: Codable, Equatable, Sendable {
    public var symbol: String
    public var size: Double
    public var weight: String

    public init(symbol: String, size: Double, weight: String = "regular") {
        self.symbol = symbol
        self.size = size
        self.weight = weight
    }
}

public struct IconsConfig: Codable, Equatable, Sendable {
    /// Строка меню. Вес замерен по оригиналу: у regular штрих на пиксель толще.
    public var menuBar = IconConfig(symbol: "timer", size: 15, weight: "light")
    /// Шестерёнка в подвале попапа.
    public var settings = IconConfig(symbol: "gearshape", size: 18, weight: "ultralight")
    /// Крестик в шапке попапа: останавливает таймер и сбрасывает его к началу фазы.
    public var reset = IconConfig(symbol: "xmark.circle", size: 22, weight: "ultralight")

    public init() {}
}

/// Шрифт как его задаёт конфиг: PostScript-имя и кегль.
public struct FontToken: Codable, Equatable, Sendable {
    public var name: String
    public var size: Double

    public init(name: String = "HelveticaNeue-Light", size: Double = 13) {
        self.name = name
        self.size = size
    }
}

/// Шрифты попапа. Строка меню и окно настроек берут системный шрифт и задают
/// только кегль — им отдельные записи не нужны.
public struct FontsConfig: Codable, Equatable, Sendable {
    /// Крупные цифры в центре кольца.
    public var digits = FontToken(name: "HelveticaNeue-Thin", size: 55)
    /// «Today N» в подвале.
    public var counter = FontToken(name: "HelveticaNeue-Light", size: 20)
    /// Название фазы в шапке.
    public var phase = FontToken(name: "HelveticaNeue-Light", size: 15)

    public init() {}
}

/// Пределы и шаг круглого регулятора времени.
public struct DialConfig: Codable, Equatable, Sendable {
    /// Сколько минут укладывается в полный оборот кольца.
    public var fullTurnMinutes = 60.0
    public var minSeconds = 1.0
    public var maxSeconds = 10_800.0
    /// Шаг перетаскивания. Одна точка дуги ≈ 5.8 секунды, поэтому мельче 5
    /// значение перестаёт быть повторяемым. Ввод с клавиатуры не округляется.
    public var dragStepSeconds = 5.0

    public init() {}

    public var dial: DurationDial {
        DurationDial(
            fullTurnMinutes: fullTurnMinutes,
            minSeconds: minSeconds,
            maxSeconds: maxSeconds,
            dragStepSeconds: dragStepSeconds
        )
    }
}
