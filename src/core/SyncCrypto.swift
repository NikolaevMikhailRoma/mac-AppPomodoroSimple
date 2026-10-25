import CryptoKit
import Foundation

// Keys and frames of docs/SYNC.md. Only CryptoKit; nothing hand-rolled.

public enum SyncCrypto {
    public enum Failure: Error { case badKey, badFrame }

    /// Random bytes for ids, nonces and tokens.
    public static func random(_ count: Int) -> Data {
        SymmetricKey(size: SymmetricKeySize(bitCount: count * 8)).withUnsafeBytes { Data($0) }
    }

    /// The long-lived key a pairing ends with. The token salts it, so the QR
    /// and the key exchange are both needed.
    public static func deviceKey(
        privateKey: P256.KeyAgreement.PrivateKey,
        peerPublicKey: Data,
        token: Data
    ) throws -> SymmetricKey {
        guard let peer = try? P256.KeyAgreement.PublicKey(x963Representation: peerPublicKey) else {
            throw Failure.badKey
        }
        let shared = try privateKey.sharedSecretFromKeyAgreement(with: peer)
        return shared.hkdfDerivedSymmetricKey(
            using: SHA256.self, salt: token, sharedInfo: Data("pomodoro-key-v1".utf8), outputByteCount: 32
        )
    }

    /// Proves to the Mac that the phone read the QR.
    public static func proof(token: Data, phonePublicKey: Data, macPublicKey: Data) -> Data {
        let message = Data("pomodoro-pair-v1".utf8) + phonePublicKey + macPublicKey
        return Data(HMAC<SHA256>.authenticationCode(for: message, using: SymmetricKey(data: token)))
    }

    public static func proofMatches(_ proof: Data, token: Data, phonePublicKey: Data, macPublicKey: Data) -> Bool {
        let message = Data("pomodoro-pair-v1".utf8) + phonePublicKey + macPublicKey
        return HMAC<SHA256>.isValidAuthenticationCode(proof, authenticating: message, using: SymmetricKey(data: token))
    }

    public static func sessionKeys(
        deviceKey: SymmetricKey,
        nonceClient: Data,
        nonceServer: Data
    ) -> (c2s: SymmetricKey, s2c: SymmetricKey) {
        func derive(_ info: String) -> SymmetricKey {
            HKDF<SHA256>.deriveKey(
                inputKeyMaterial: deviceKey, salt: nonceClient + nonceServer,
                info: Data(info.utf8), outputByteCount: 32
            )
        }
        return (derive("pomodoro-c2s-v1"), derive("pomodoro-s2c-v1"))
    }
}

/// One connection's encryption: a key and a counter for each direction.
public struct SessionCipher: Sendable {
    private let sendKey: SymmetricKey
    private let receiveKey: SymmetricKey
    private var sent: UInt64 = 0
    private var received: UInt64 = 0

    public init(sendKey: SymmetricKey, receiveKey: SymmetricKey) {
        self.sendKey = sendKey
        self.receiveKey = receiveKey
    }

    public mutating func seal(_ plaintext: Data) throws -> Data {
        let box = try AES.GCM.seal(plaintext, using: sendKey, nonce: Self.nonce(sent))
        sent += 1
        // A fresh Data: CryptoKit hands out slices that do not start at index 0.
        return Data(box.ciphertext + box.tag)
    }

    /// Throws on a forged, reordered or replayed frame; the caller closes the connection.
    public mutating func open(_ payload: Data) throws -> Data {
        guard payload.count >= 16 else { throw SyncCrypto.Failure.badFrame }
        let box = try AES.GCM.SealedBox(
            nonce: Self.nonce(received), ciphertext: payload.dropLast(16), tag: payload.suffix(16)
        )
        let plaintext = try AES.GCM.open(box, using: receiveKey)
        received += 1
        return plaintext
    }

    static func nonce(_ counter: UInt64) -> AES.GCM.Nonce {
        try! AES.GCM.Nonce(data: Data(count: 4) + withUnsafeBytes(of: counter.bigEndian) { Data($0) })
    }
}

/// Splits a TCP byte stream into frames: a 4-byte big-endian length, then the payload.
public struct FrameReader: Sendable {
    public static let maxLength = 16384

    private var buffer = Data()

    public init() {}

    public static func frame(_ payload: Data) -> Data {
        withUnsafeBytes(of: UInt32(payload.count).bigEndian) { Data($0) } + payload
    }

    public mutating func append(_ bytes: Data) {
        buffer.append(bytes)
    }

    /// The next whole frame, nil when more bytes are needed. Throws on a
    /// length the protocol does not allow.
    public mutating func next() throws -> Data? {
        guard buffer.count >= 4 else { return nil }
        let length = buffer.prefix(4).reduce(0) { $0 << 8 | Int($1) }
        guard (1...Self.maxLength).contains(length) else { throw SyncCrypto.Failure.badFrame }
        guard buffer.count >= 4 + length else { return nil }
        let payload = Data(buffer.dropFirst(4).prefix(length))
        buffer = Data(buffer.dropFirst(4 + length))
        return payload
    }
}
