import CryptoKit
import Foundation
import Network
import Security

/// The Mac this phone is paired with. The device key is in the Keychain,
/// readable on this iPhone only and after its first unlock (the Lock Screen
/// button needs it while the phone is locked), and never in a backup.
/// Everything else here is not secret and lives in UserDefaults.
@MainActor
final class PairedMac {
    private static let service = "com.nikolaev.pomodoro.sync"
    private static let account = "deviceKey"

    private let defaults = UserDefaults.standard

    /// Not a secret: the Mac uses it to find this phone's key.
    let phoneId: String

    init() {
        if let id = defaults.string(forKey: "PhoneId") {
            phoneId = id
        } else {
            phoneId = SymmetricKey(size: .bits128).withUnsafeBytes { Data($0) }.base64URL
            defaults.set(phoneId, forKey: "PhoneId")
        }
    }

    var macId: String? { defaults.string(forKey: "MacId") }

    /// How the Mac called itself last time, "MacBook Pro" and "mac"; nil before it said.
    var macName: String? { defaults.string(forKey: "MacName") }
    var macKind: String? { defaults.string(forKey: "MacKind") }

    func saveIdentity(name: String, kind: String) {
        guard !name.isEmpty else { return }
        defaults.set(String(name.prefix(40)), forKey: "MacName")
        defaults.set(String(kind.prefix(20)), forKey: "MacKind")
    }

    /// The last address the Mac answered on, for when discovery finds nothing.
    var lastAddress: NWEndpoint? {
        guard let host = defaults.string(forKey: "MacHost"),
              let port = NWEndpoint.Port(rawValue: UInt16(clamping: defaults.integer(forKey: "MacPort"))) else { return nil }
        return .hostPort(host: NWEndpoint.Host(host), port: port)
    }

    func saveAddress(_ endpoint: NWEndpoint?) {
        guard case .hostPort(let host, let port) = endpoint else { return }
        let text: String
        switch host {
        case .ipv4(let address): text = "\(address)"
        case .ipv6(let address): text = "\(address)"
        case .name(let name, _): text = name
        @unknown default: return
        }
        defaults.set(text, forKey: "MacHost")
        defaults.set(Int(port.rawValue), forKey: "MacPort")
    }

    /// Nil when not paired, or when the Keychain lost the key.
    func deviceKey() -> SymmetricKey? {
        var query = Self.item
        query[kSecReturnData as String] = true
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return SymmetricKey(data: data)
    }

    /// False when the Keychain refused: then nothing is stored.
    func save(macId: String, key: SymmetricKey) -> Bool {
        SecItemDelete(Self.item as CFDictionary)
        var item = Self.item
        item[kSecValueData as String] = key.withUnsafeBytes { Data($0) }
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { return false }
        defaults.set(macId, forKey: "MacId")
        return true
    }

    func forget() {
        SecItemDelete(Self.item as CFDictionary)
        for key in ["MacId", "MacName", "MacKind", "MacHost", "MacPort"] {
            defaults.removeObject(forKey: key)
        }
    }

    private static var item: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
