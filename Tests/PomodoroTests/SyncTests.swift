import CryptoKit
import Foundation
import Testing
@testable import PomodoroCore

private let t0 = Date(timeIntervalSince1970: 1_000_000)

/// docs/sync-vectors.json: the same file the Android tests read.
nonisolated(unsafe) private let vectors: [String: Any] = {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("docs/sync-vectors.json")
    return try! JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
}()

private func section(_ name: String) -> [String: Any] { vectors[name] as! [String: Any] }
private func bytes(_ o: [String: Any], _ key: String) -> Data { Data(base64URL: o[key])! }
private func raw(_ key: SymmetricKey) -> Data { key.withUnsafeBytes { Data($0) } }

@Suite("Sync crypto vectors")
struct SyncCryptoTests {
    var c: [String: Any] { section("crypto") }

    @Test("both sides derive the device key from the QR token and the key exchange")
    func deviceKey() throws {
        let mac = try P256.KeyAgreement.PrivateKey(rawRepresentation: bytes(c, "macPrivate"))
        let phone = try P256.KeyAgreement.PrivateKey(rawRepresentation: bytes(c, "phonePrivate"))
        #expect(mac.publicKey.x963Representation == bytes(c, "macPublic"))
        #expect(phone.publicKey.x963Representation == bytes(c, "phonePublic"))

        let onMac = try SyncCrypto.deviceKey(privateKey: mac, peerPublicKey: bytes(c, "phonePublic"), token: bytes(c, "token"))
        let onPhone = try SyncCrypto.deviceKey(privateKey: phone, peerPublicKey: bytes(c, "macPublic"), token: bytes(c, "token"))
        #expect(raw(onMac) == bytes(c, "deviceKey"))
        #expect(raw(onPhone) == bytes(c, "deviceKey"))
    }

    @Test("the pairing proof matches, and fails with another token")
    func proof() {
        let proof = SyncCrypto.proof(token: bytes(c, "token"), phonePublicKey: bytes(c, "phonePublic"), macPublicKey: bytes(c, "macPublic"))
        #expect(proof == bytes(c, "proof"))
        #expect(SyncCrypto.proofMatches(proof, token: bytes(c, "token"), phonePublicKey: bytes(c, "phonePublic"), macPublicKey: bytes(c, "macPublic")))
        #expect(!SyncCrypto.proofMatches(proof, token: Data(count: 16), phonePublicKey: bytes(c, "phonePublic"), macPublicKey: bytes(c, "macPublic")))
    }

    @Test("session keys and frames match the vectors in both directions")
    func frames() throws {
        let keys = SyncCrypto.sessionKeys(
            deviceKey: SymmetricKey(data: bytes(c, "deviceKey")),
            nonceClient: bytes(c, "nonceClient"), nonceServer: bytes(c, "nonceServer")
        )
        #expect(raw(keys.c2s) == bytes(c, "c2s"))
        #expect(raw(keys.s2c) == bytes(c, "s2c"))

        var phone = SessionCipher(sendKey: keys.c2s, receiveKey: keys.s2c)
        var mac = SessionCipher(sendKey: keys.s2c, receiveKey: keys.c2s)
        for frame in c["frames"] as! [[String: Any]] {
            let text = Data((frame["plaintext"] as! String).utf8)
            let payload = bytes(frame, "payload")
            if frame["key"] as! String == "c2s" {
                #expect(try phone.seal(text) == payload)
                #expect(try mac.open(payload) == text)
            } else {
                #expect(try mac.seal(text) == payload)
                #expect(try phone.open(payload) == text)
            }
        }
    }

    @Test("a replayed or altered frame does not open")
    func replay() throws {
        let key = SymmetricKey(data: bytes(c, "c2s"))
        var sender = SessionCipher(sendKey: key, receiveKey: key)
        var receiver = SessionCipher(sendKey: key, receiveKey: key)
        let first = try sender.seal(Data("one".utf8))
        _ = try receiver.open(first)
        #expect(throws: (any Error).self) { try receiver.open(first) }

        var fresh = SessionCipher(sendKey: key, receiveKey: key)
        var altered = first
        altered[0] ^= 1
        #expect(throws: (any Error).self) { try fresh.open(altered) }
    }
}

@Suite("Sync wire format")
struct SyncWireTests {

    @Test("the pairing link round-trips and rejects anything else")
    func pairLink() {
        let v = section("pairLink")
        let valid = v["valid"] as! [String: Any]
        let link = PairLink(link: valid["link"] as! String)
        #expect(link?.macId == valid["id"] as? String)
        #expect(link?.publicKey == bytes(valid, "publicKey"))
        #expect(link?.token == bytes(valid, "token"))
        #expect(link?.addresses == valid["addresses"] as? [String])
        #expect(link?.port == 52025)
        #expect(link?.link == valid["link"] as? String)
        for bad in v["invalid"] as! [String] {
            #expect(PairLink(link: bad) == nil, "\(bad)")
        }
    }

    @Test("a state reads from JSON and survives a round trip")
    func state() throws {
        let v = section("state")
        let o = try JSONSerialization.jsonObject(with: Data((v["json"] as! String).utf8)) as! [String: Any]
        let s = try #require(EngineState(json: o))
        #expect(s.phase == .shortBreak)
        #expect(s.runState == .running)
        #expect(s.phaseDuration == 300)
        #expect(s.endsAt == Date(timeIntervalSince1970: 1792761800.5))
        #expect(s.completedToday == 3)
        #expect(s.sinceLongBreak == 3)
        #expect(s.day == "2026-10-23")
        #expect(s.changedAt == Date(timeIntervalSince1970: 1792761500.5))

        let message = SyncMessage.state(s, sentAt: t0)
        #expect(SyncMessage(data: message.data) == message)
    }

    @Test("remote times move onto the local clock")
    func shift() {
        let v = section("shift")
        let remote = v["remote"] as! [String: Double], local = v["local"] as! [String: Double]
        var s = EngineState.initial(settings: IntervalSettings())
        s.runState = .running
        s.endsAt = Date(timeIntervalSince1970: remote["endsAt"]!)
        s.changedAt = Date(timeIntervalSince1970: remote["changedAt"]!)
        let shifted = s.shifted(by: (v["receivedAt"] as! Double) - (v["sentAt"] as! Double))
        #expect(shifted.endsAt == Date(timeIntervalSince1970: local["endsAt"]!))
        #expect(shifted.changedAt == Date(timeIntervalSince1970: local["changedAt"]!))

        let untouched = section("shiftUntouched")
        s.changedAt = Date(timeIntervalSince1970: 0)
        let offset = (untouched["receivedAt"] as! Double) - (untouched["sentAt"] as! Double)
        #expect(s.shifted(by: offset).changedAt == Date(timeIntervalSince1970: 0))
        #expect(SyncRules.shifted(Date(timeIntervalSince1970: 0), by: offset) == Date(timeIntervalSince1970: 0))
    }

    @Test("the later change wins, and the Mac within a second")
    func merge() {
        for case let m as [String: Any] in vectors["merge"] as! [Any] {
            let adopt = SyncRules.shouldAdopt(
                local: Date(timeIntervalSince1970: m["local"] as! Double),
                remote: Date(timeIntervalSince1970: m["remote"] as! Double),
                receiverIsMac: m["receiver"] as! String == "mac",
                localAdopted: m["localAdopted"] as? Bool ?? false
            )
            #expect(adopt == m["adopt"] as! Bool, "\(m["why"]!)")
        }
    }

    @Test("interval settings: the message, and defaults never win")
    func intervals() throws {
        let v = section("intervals")
        let m = try #require(SyncMessage(data: Data((v["json"] as! String).utf8)))
        guard case .intervals(let i, let changedAt, let sentAt) = m else { Issue.record("not intervals"); return }
        #expect(i == IntervalSettings(workMinutes: 60, shortBreakMinutes: 5, longBreakMinutes: 15, longBreakAfter: 4))
        #expect(changedAt == Date(timeIntervalSince1970: 900.25))
        #expect(sentAt == Date(timeIntervalSince1970: 1000.5))
        #expect(SyncMessage(data: m.data) == m)

        for case let c as [String: Any] in vectors["mergeIntervals"] as! [Any] {
            let adopt = SyncRules.shouldAdoptIntervals(
                local: Date(timeIntervalSince1970: c["local"] as! Double),
                remote: Date(timeIntervalSince1970: c["remote"] as! Double),
                receiverIsMac: c["receiver"] as! String == "mac"
            )
            #expect(adopt == c["adopt"] as! Bool, "\(c["why"]!)")
        }
    }

    @Test("hello, pair and a version from the future")
    func handshake() {
        let nonce = Data(count: 16)
        for m in [SyncMessage.hello(id: "a", nonce: nonce, name: "MacBook", kind: DeviceKind.mac),
                  .pair(id: "a", name: "phone", kind: DeviceKind.android, publicKey: Data(count: 65), nonce: nonce, proof: Data(count: 32)),
                  .error("unknown-device"), .unpair, .ping] {
            #expect(SyncMessage(data: m.data) == m)
        }
        #expect(SyncMessage(data: Data(#"{"type":"hello","v":2,"id":"a"}"#.utf8)) == .unsupportedVersion)
        #expect(SyncMessage(data: Data(#"{"type":"later"}"#.utf8)) == .unknown)
        // An older build sends no name or kind.
        #expect(SyncMessage(data: Data(#"{"type":"hello","v":1,"id":"a","nonce":"AAAAAAAAAAAAAAAAAAAAAA"}"#.utf8))
                == .hello(id: "a", nonce: Data(count: 16)))
        #expect(DeviceKind.title("android") == "Android")
        #expect(DeviceKind.title("ios") == "iPhone")
        #expect(SyncMessage(data: Data("not json".utf8)) == nil)
    }

    @Test("frames split out of a stream however it arrives")
    func frames() throws {
        var reader = FrameReader()
        let stream = FrameReader.frame(Data("one".utf8)) + FrameReader.frame(Data("two".utf8))
        reader.append(stream.prefix(5))
        #expect(try reader.next() == nil)
        reader.append(stream.dropFirst(5))
        #expect(try reader.next() == Data("one".utf8))
        #expect(try reader.next() == Data("two".utf8))
        #expect(try reader.next() == nil)

        var hostile = FrameReader()
        hostile.append(Data([0, 1, 0, 0]))
        #expect(throws: (any Error).self) { try hostile.next() }
    }
}

@Suite("Change time")
struct ChangeTimeTests {

    @Test("buttons stamp the moment, an interval running out stamps its end")
    func stamps() {
        var e = PomodoroEngine()
        e.start(now: t0)
        #expect(e.state.changedAt == t0)
        _ = e.update(now: t0.addingTimeInterval(25 * 60 + 0.3))
        #expect(e.state.changedAt == t0.addingTimeInterval(25 * 60))
        e.setPhaseDuration(60, now: t0.addingTimeInterval(2000))
        #expect(e.state.changedAt == t0.addingTimeInterval(2000))
        e.applySettings(IntervalSettings(shortBreakMinutes: 7), now: t0.addingTimeInterval(3000))
        #expect(e.state.changedAt == t0.addingTimeInterval(3000))
        // The count rolling over is not a change.
        e.rollOverDay("2026-10-24")
        #expect(e.state.changedAt == t0.addingTimeInterval(3000))
    }

    @Test("an adopted state replaces everything and fires nothing")
    func adopt() {
        var e = PomodoroEngine()
        var other = PomodoroEngine()
        other.start(now: t0)
        e.adopt(other.state)
        #expect(e.state == other.state)
        #expect(e.update(now: t0.addingTimeInterval(60)).isEmpty)
        #expect(e.remaining == 24 * 60)
    }
}
