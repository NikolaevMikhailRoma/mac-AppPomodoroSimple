import CryptoKit
import Foundation
import Observation
import PomodoroCore
import Security

/// The phones this Mac is paired with. Ids and names live in UserDefaults,
/// so the list shows without touching the Keychain; each phone's key lives in
/// the Keychain and is read once per launch, when that phone first connects.
/// The read can wait on a password prompt (after every rebuild, see
/// known_issues.md), so it runs off the main thread and is shared by
/// connections that arrive meanwhile.
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
    private nonisolated static let keychainService = "com.nikolaev.pomodoro.sync"

    /// Not a secret: the phone uses it to tell its Mac from others on the network.
    let macId: String
    private(set) var list: [Device]

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var keys: [String: SymmetricKey] = [:]
    @ObservationIgnored private var reading: [String: Task<SymmetricKey?, Never>] = [:]

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

    /// Nil when the phone is not paired, or the Keychain refused (the user
    /// denied the prompt); `contains(_:)` tells the two apart.
    func key(for id: String) async -> SymmetricKey? {
        guard contains(id) else { return nil }
        if let key = keys[id] { return key }
        if let pending = reading[id] { return await pending.value }
        let read = Task.detached { Self.readKey(id) }
        reading[id] = read
        let key = await read.value
        reading[id] = nil
        // Removed while the prompt was open: do not keep it.
        if let key, contains(id) { keys[id] = key }
        return key
    }

    func contains(_ id: String) -> Bool {
        list.contains { $0.id == id }
    }

    /// False when the Keychain refused the key; the phone then stays unpaired.
    func add(id: String, name: String, kind: String, key: SymmetricKey) -> Bool {
        SecItemDelete(Self.query(id) as CFDictionary)
        let data = key.withUnsafeBytes { Data($0) }
        let status = SecItemAdd(Self.query(id).merging([
            kSecValueData as String: data,
            kSecAttrLabel as String: "Pomodoro: \(name)",
        ]) { a, _ in a } as CFDictionary, nil)
        guard status == errSecSuccess else { return false }
        keys[id] = key
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
        SecItemDelete(Self.query(id) as CFDictionary)
        keys[id] = nil
        list.removeAll { $0.id == id }
        save()
    }

    static func randomId() -> String {
        Data((0..<16).map { _ in UInt8.random(in: .min ... .max) }).base64URL
    }

    private nonisolated static func readKey(_ id: String) -> SymmetricKey? {
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query(id).merging([
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]) { a, _ in a } as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return SymmetricKey(data: data)
    }

    private nonisolated static func query(_ id: String) -> [String: Any] {
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
