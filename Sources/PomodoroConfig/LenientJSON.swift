import Foundation

/// Значение JSON в том виде, в каком оно лежит в файле.
///
/// Нужно ровно для одного: наложить пользовательский `config.json` поверх
/// дефолтов так, чтобы кривой ключ терял только себя, а не утаскивал за собой
/// весь файл. Благодаря этому структурам конфига не нужен свой `init(from:)` —
/// хватает значения в объявлении поля.
enum JSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    /// Накладывает `user` на `base`. Объекты сливаются по ключам; значение
    /// принимается, только если его тип совпал с дефолтным. Поэтому
    /// `"fontSize": "big"` теряет один ключ, а соседние в той же секции выживают.
    static func merged(_ base: JSONValue, _ user: JSONValue) -> JSONValue {
        guard case .object(let b) = base, case .object(let u) = user else {
            return sameKind(base, user) ? user : base
        }
        var out = b
        for (key, value) in u {
            out[key] = b[key].map { merged($0, value) } ?? value
        }
        return .object(out)
    }

    /// Заменяет имена цветов на значения из секции `palette`. Идёт по всему
    /// дереву, кроме самой секции: строка, совпавшая с ключом палитры, становится
    /// её значением, остальные остаются как есть — поэтому литерал `#RRGGBB`
    /// в секции по-прежнему работает.
    ///
    /// Отсюда единственное правило палитры: не называй цвет так же, как имя
    /// шрифта или SF-символа, иначе подменится и оно.
    static func resolvingPalette(_ root: JSONValue) -> JSONValue {
        guard case .object(let o) = root,
              case .object(let entries)? = o["palette"] else { return root }

        var palette: [String: JSONValue] = [:]
        for (name, value) in entries where value.isString { palette[name] = value }

        var out = o
        for (key, value) in o where key != "palette" {
            out[key] = substituting(value, palette)
        }
        return .object(out)
    }

    private static func substituting(_ value: JSONValue, _ palette: [String: JSONValue]) -> JSONValue {
        switch value {
        case .string(let name): return palette[name] ?? value
        case .array(let items): return .array(items.map { substituting($0, palette) })
        case .object(let fields): return .object(fields.mapValues { substituting($0, palette) })
        default: return value
        }
    }

    private var isString: Bool {
        if case .string = self { return true }
        return false
    }

    private static func sameKind(_ a: JSONValue, _ b: JSONValue) -> Bool {
        switch (a, b) {
        case (.null, .null), (.bool, .bool), (.number, .number),
             (.string, .string), (.array, .array), (.object, .object): return true
        default: return false
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        // Bool раньше Double: JSONDecoder не путает true с 1, но порядок важен.
        if c.decodeNil() {
            self = .null
        } else if let v = try? c.decode(Bool.self) {
            self = .bool(v)
        } else if let v = try? c.decode(Double.self) {
            self = .number(v)
        } else if let v = try? c.decode(String.self) {
            self = .string(v)
        } else if let v = try? c.decode([JSONValue].self) {
            self = .array(v)
        } else {
            self = .object(try c.decode([String: JSONValue].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }
}
