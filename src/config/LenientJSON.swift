import Foundation

/// A JSON value exactly as it sits in the file.
///
/// It exists for one job: to lay the user's `config.json` over the defaults so
/// that a broken key loses only itself instead of taking the whole file down.
/// That is why the config types need no `init(from:)` of their own — a value in
/// the property declaration is enough.
enum JSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    /// Lays `user` over `base`. Objects merge key by key, and a value is taken
    /// only when its type matches the default. So `"fontSize": "big"` loses that
    /// one key while its neighbours in the same section survive.
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

    /// Replaces colour names with the values from the `palette` section. It
    /// walks the whole tree except that section: a string matching a palette key
    /// becomes its value, everything else is left alone — which is why a literal
    /// `#RRGGBB` still works anywhere.
    ///
    /// Hence the one rule of the palette: never name a colour after a font or an
    /// SF Symbol, or that name gets substituted too.
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
        // Bool before Double: JSONDecoder does not confuse true with 1, but the order matters.
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
