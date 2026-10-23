import CryptoKit
import Foundation
import Observation
import PomodoroCore
import Security

/// The phones this Mac is paired with. Ids and names live in UserDefaults,
/// so the list shows without touching the Keychain; each phone's key lives in
/// the Keychain and is read only when that phone connects.
@MainActor
@Observable
final class PairedDevices {
    struct Device: Codable, Identifiable, Equatable {
        let id: String
        var name: String
        /// `DeviceKind`; phones paired before kinds existed were all Android.
        var kind: String

        init(id: String, name: String, kind: String) {
            self.id = id
            self.name = name
            self.kind = kind
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            name = c.value(.name, or: "Phone")
            kind = c.value(.kind, or: DeviceKind.android)
        }
    }

    private static let listKey = "SyncDevices"
    private static let macIdKey = "SyncMacId"
    private static let keychainService = "com.nikolaev.pomodoro.sync"

    /// Not a secret: the phone uses it to tell its Mac from others on the network.
    let macId: String
    private(set) var list: [Device]

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let id = defaults.string(forKey: Self.macIdKey) {
            macId = id
        } else {
            macId = Self.randomId()
            defaults.set(macId, forKey: Self.macIdKey)
        }
        list = defaults.data(forKey: Self.listKey)
            .flatMap { try? JSONDecoder().decode([Device].self, from: $0) } ?? []
    }

    func key(for id: String) -> SymmetricKey? {
        guard list.contains(where: { $0.id == id }) else { return nil }
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query(id).merging([
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]) { a, _ in a } as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return SymmetricKey(data: data)
    }

    /// False when the Keychain refused the key; the phone then stays unpaired.
    func add(id: String, name: String, kind: String, key: SymmetricKey) -> Bool {
        SecItemDelete(query(id) as CFDictionary)
        let data = key.withUnsafeBytes { Data($0) }
        let status = SecItemAdd(query(id).merging([
            kSecValueData as String: data,
            kSecAttrLabel as String: "Pomodoro: \(name)",
        ]) { a, _ in a } as CFDictionary, nil)
        guard status == errSecSuccess else { return false }
        list.removeAll { $0.id == id }
        list.append(Device(
            id: id,
            name: name.isEmpty ? "Phone" : String(name.prefix(40)),
            kind: kind.isEmpty ? DeviceKind.android : String(kind.prefix(20))
        ))
        save()
        return true
    }

    func remove(id: String) {
        SecItemDelete(query(id) as CFDictionary)
        list.removeAll { $0.id == id }
        save()
    }

    static func randomId() -> String {
        Data((0..<16).map { _ in UInt8.random(in: .min ... .max) }).base64URL
    }

    private func query(_ id: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: id,
        ]
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(list), forKey: Self.listKey)
    }
}
