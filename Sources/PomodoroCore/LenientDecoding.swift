import Foundation

extension KeyedDecodingContainer {
    /// Reads a key, falling back when it is missing, null, or the wrong type.
    ///
    /// Swift's synthesised `Codable` ignores a property's default value and
    /// throws on a missing key, which would mean one typo in `config.json`
    /// discards the entire file. Every config and settings type decodes through
    /// this instead, so unknown files, half-written files and files from an
    /// older build all still load.
    func value<T: Decodable>(_ key: Key, or fallback: T) -> T {
        ((try? decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
    }
}
