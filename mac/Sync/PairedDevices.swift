import CryptoKit
import Foundation
import Observation
import PomodoroCore
import PomodoroSync
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
            macId = SyncCrypto.random(16).base64URL
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
        let read = Task.detached { DeviceKeychain.read(id) }
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
        guard DeviceKeychain.save(key, for: id, attributes: [kSecAttrLabel as String: "Pomodoro: \(name)"]) else {
            return false
        }
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
        DeviceKeychain.delete(id)
        keys[id] = nil
        list.removeAll { $0.id == id }
        save()
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(list), forKey: Self.listKey)
    }
}
