import CryptoKit
import Foundation
import Security

/// Device keys in the Keychain, one generic password each under the sync
/// service: on the Mac one per phone, by the phone's id; on the iPhone the
/// one for its Mac.
public enum DeviceKeychain {
    private static let service = "com.nikolaev.pomodoro.sync"

    /// Nil when there is none, or when the Keychain refused (the user denied the Mac's prompt).
    public static func read(_ account: String) -> SymmetricKey? {
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query(account).merging([
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]) { a, _ in a } as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return SymmetricKey(data: data)
    }

    /// Replaces the account's key, with `attributes` such as a label or who may read it.
    /// False when the Keychain refused: then nothing is stored.
    public static func save(_ key: SymmetricKey, for account: String, attributes: [String: Any]) -> Bool {
        delete(account)
        var item = query(account).merging(attributes) { a, _ in a }
        item[kSecValueData as String] = key.withUnsafeBytes { Data($0) }
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    public static func delete(_ account: String) {
        SecItemDelete(query(account) as CFDictionary)
    }

    private static func query(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
