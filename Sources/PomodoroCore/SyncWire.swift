import Foundation

// What the Mac and the phone send each other, and how they merge it.
// The protocol is docs/SYNC.md; docs/sync-vectors.json pins every detail.

public enum SyncMessage: Equatable, Sendable {
    /// `name` and `kind` describe the sender for the other side's device list; empty from older builds.
    case hello(id: String, nonce: Data, name: String = "", kind: String = "")
    case pair(id: String, name: String, kind: String = "", publicKey: Data, nonce: Data, proof: Data)
    case error(String)
    case state(EngineState, sentAt: Date)
    case intervals(IntervalSettings, changedAt: Date, sentAt: Date)
    case unpair
    case ping
    /// A hello or pair from another protocol version.
    case unsupportedVersion
    /// A type this version does not know: ignored.
    case unknown

    public static let version = 1

    /// Nil when the frame is not a JSON object or a known type lacks a field.
    public init?(data: Data) {
        guard let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let type = o["type"] as? String else { return nil }
        switch type {
        case "hello", "pair":
            guard o["v"] as? Int == Self.version else { self = .unsupportedVersion; return }
            guard let id = o["id"] as? String, let nonce = Data(base64URL: o["nonce"]), nonce.count == 16
            else { return nil }
            let name = o["name"] as? String ?? "", kind = o["kind"] as? String ?? ""
            if type == "hello" {
                self = .hello(id: id, nonce: nonce, name: name, kind: kind)
                return
            }
            guard let pub = Data(base64URL: o["pub"]), let proof = Data(base64URL: o["proof"]) else { return nil }
            self = .pair(id: id, name: name, kind: kind, publicKey: pub, nonce: nonce, proof: proof)
        case "error":
            self = .error(o["reason"] as? String ?? "")
        case "state":
            guard let sentAt = o["sentAt"] as? Double,
                  let state = (o["state"] as? [String: Any]).flatMap(EngineState.init(json:)) else { return nil }
            self = .state(state, sentAt: Date(timeIntervalSince1970: sentAt))
        case "intervals":
            guard let sentAt = o["sentAt"] as? Double, let changedAt = o["changedAt"] as? Double,
                  let intervals = (o["intervals"] as? [String: Any]).flatMap(IntervalSettings.init(json:)) else { return nil }
            self = .intervals(intervals, changedAt: Date(timeIntervalSince1970: changedAt),
                              sentAt: Date(timeIntervalSince1970: sentAt))
        case "unpair":
            self = .unpair
        case "ping":
            self = .ping
        default:
            self = .unknown
        }
    }

    public var data: Data {
        let o: [String: Any]
        switch self {
        case .hello(let id, let nonce, let name, let kind):
            o = ["type": "hello", "v": Self.version, "id": id, "nonce": nonce.base64URL, "name": name, "kind": kind]
        case .pair(let id, let name, let kind, let pub, let nonce, let proof):
            o = ["type": "pair", "v": Self.version, "id": id, "name": name, "kind": kind,
                 "pub": pub.base64URL, "nonce": nonce.base64URL, "proof": proof.base64URL]
        case .error(let reason):
            o = ["type": "error", "reason": reason]
        case .state(let state, let sentAt):
            o = ["type": "state", "sentAt": sentAt.timeIntervalSince1970, "state": state.json]
        case .intervals(let intervals, let changedAt, let sentAt):
            o = ["type": "intervals", "sentAt": sentAt.timeIntervalSince1970,
                 "changedAt": changedAt.timeIntervalSince1970, "intervals": intervals.json]
        case .unpair:
            o = ["type": "unpair"]
        case .ping, .unsupportedVersion, .unknown:
            o = ["type": "ping"]
        }
        return try! JSONSerialization.data(withJSONObject: o, options: [.sortedKeys])
    }
}

extension EngineState {
    public init?(json o: [String: Any]) {
        guard let phase = (o["phase"] as? String).flatMap(Phase.init(rawValue:)),
              let runState = (o["runState"] as? String).flatMap(RunState.init(rawValue:)),
              let duration = o["phaseDuration"] as? Double, duration > 0,
              let remaining = o["remaining"] as? Double,
              let changedAt = o["changedAt"] as? Double else { return nil }
        let endsAt = (o["endsAt"] as? Double).map(Date.init(timeIntervalSince1970:))
        if runState == .running && endsAt == nil { return nil }
        self.init(
            phase: phase,
            runState: runState,
            phaseDuration: duration,
            remaining: min(max(remaining, 0), duration),
            endsAt: runState == .running ? endsAt : nil,
            completedToday: max(o["completedToday"] as? Int ?? 0, 0),
            sinceLongBreak: max(o["sinceLongBreak"] as? Int ?? 0, 0),
            day: o["day"] as? String ?? "",
            changedAt: Date(timeIntervalSince1970: changedAt)
        )
    }

    public var json: [String: Any] {
        [
            "phase": phase.rawValue,
            "runState": runState.rawValue,
            "phaseDuration": phaseDuration,
            "remaining": remaining,
            "endsAt": endsAt.map { $0.timeIntervalSince1970 as Any } ?? NSNull(),
            "completedToday": completedToday,
            "sinceLongBreak": sinceLongBreak,
            "day": day,
            "changedAt": changedAt.timeIntervalSince1970,
        ]
    }

    /// Moves the sender's times onto the receiver's clock.
    public func shifted(by offset: TimeInterval) -> EngineState {
        var s = self
        s.endsAt = endsAt?.addingTimeInterval(offset)
        s.changedAt = SyncRules.shifted(changedAt, by: offset)
        return s
    }

    /// "2026-10-23" in the local calendar: the day the count belongs to.
    public static func day(of date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

extension IntervalSettings {
    public init?(json o: [String: Any]) {
        guard let work = o["workMinutes"] as? Double, let short = o["shortBreakMinutes"] as? Double,
              let long = o["longBreakMinutes"] as? Double, let after = o["longBreakAfter"] as? Int,
              work > 0, short > 0, long > 0, after > 0 else { return nil }
        self.init(workMinutes: work, shortBreakMinutes: short, longBreakMinutes: long, longBreakAfter: after)
    }

    public var json: [String: Any] {
        ["workMinutes": workMinutes, "shortBreakMinutes": shortBreakMinutes,
         "longBreakMinutes": longBreakMinutes, "longBreakAfter": longBreakAfter]
    }
}

/// What a device is, as `kind` names it on the wire.
public enum DeviceKind {
    public static let mac = "mac"
    public static let android = "android"

    /// For the lists of paired devices: "Mac", "Android", "iPhone", "Windows".
    public static func title(_ kind: String) -> String {
        switch kind {
        case mac: return "Mac"
        case android: return "Android"
        case "ios": return "iPhone"
        case "windows": return "Windows"
        default: return kind.prefix(1).uppercased() + kind.dropFirst()
        }
    }
}

public enum SyncRules {
    /// Changes closer than this count as simultaneous, and the Mac wins.
    public static let tieWindow: TimeInterval = 1

    /// A change time on the receiver's clock. 0 stays 0: "never changed".
    public static func shifted(_ changedAt: Date, by offset: TimeInterval) -> Date {
        changedAt == Date(timeIntervalSince1970: 0) ? changedAt : changedAt.addingTimeInterval(offset)
    }

    /// Whether the receiver takes the other device's state. Both times are on
    /// the receiver's clock. A state nobody changed (time 0) always loses, and
    /// of two such states the phone's wins: it kept its timer, the Mac did not.
    /// `localAdopted`: the Mac's current state came from a phone, so the tie
    /// window (for changes on both devices at once) does not apply.
    public static func shouldAdopt(local: Date, remote: Date, receiverIsMac: Bool, localAdopted: Bool = false) -> Bool {
        let never = Date(timeIntervalSince1970: 0)
        guard receiverIsMac else { return remote != never && remote.timeIntervalSince(local) >= -tieWindow }
        return local == never || remote.timeIntervalSince(local) > (localAdopted ? 0 : tieWindow)
    }

    /// The same for interval settings, except that defaults (time 0) never
    /// win, not even over other defaults.
    public static func shouldAdoptIntervals(local: Date, remote: Date, receiverIsMac: Bool) -> Bool {
        let never = Date(timeIntervalSince1970: 0)
        guard remote != never else { return false }
        return local == never || (receiverIsMac
            ? remote.timeIntervalSince(local) > tieWindow
            : remote.timeIntervalSince(local) >= -tieWindow)
    }
}

/// What the pairing QR on the Mac says.
public struct PairLink: Equatable, Sendable {
    public var macId: String
    public var publicKey: Data
    public var token: Data
    public var addresses: [String]
    public var port: UInt16

    public init(macId: String, publicKey: Data, token: Data, addresses: [String], port: UInt16) {
        self.macId = macId
        self.publicKey = publicKey
        self.token = token
        self.addresses = addresses
        self.port = port
    }

    public init?(link: String) {
        guard let url = URLComponents(string: link), url.scheme == "pomodoro", url.host == "pair" else { return nil }
        let q = Dictionary((url.queryItems ?? []).map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { a, _ in a })
        guard q["v"] == String(SyncMessage.version),
              let id = q["id"], !id.isEmpty,
              let key = Data(base64URL: q["k"]), key.count == 65,
              let token = Data(base64URL: q["t"]), token.count == 16,
              let port = q["p"].flatMap(UInt16.init), port > 0 else { return nil }
        let addresses = (q["a"] ?? "").split(separator: ",").map(String.init)
        self.init(macId: id, publicKey: key, token: token, addresses: addresses, port: port)
    }

    public var link: String {
        "pomodoro://pair?v=\(SyncMessage.version)&id=\(macId)&k=\(publicKey.base64URL)&t=\(token.base64URL)"
            + "&a=\(addresses.joined(separator: ","))&p=\(port)"
    }
}

extension Data {
    public init?(base64URL value: Any?) {
        guard var s = value as? String else { return nil }
        s = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        s += String(repeating: "=", count: (4 - s.count % 4) % 4)
        self.init(base64Encoded: s)
    }

    public var base64URL: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
