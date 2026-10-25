import CryptoKit
import Foundation
import Network
import Observation
import PomodoroCore
import PomodoroSync
import SystemConfiguration

/// The Mac's side of docs/SYNC.md: listens for paired phones, runs the
/// pairing QR, and passes timer states between the phones and the timer.
/// It listens only while there is a paired phone or a QR on screen.
@MainActor
@Observable
final class SyncServer {
    static let preferredPort: UInt16 = 52025
    static let pairingLifetime: TimeInterval = 120
    /// The time a new connection has to say hello.
    static let helloLimit: TimeInterval = 10
    /// Dragging the ring changes the state with every mouse move; phones get the newest this often.
    static let sendInterval: TimeInterval = 0.1
    /// This Mac's name in System Settings → General → Sharing, for the phone's device list.
    static var macName: String { (SCDynamicStoreCopyComputerName(nil, nil) as String?) ?? "Mac" }

    struct Pairing {
        let link: PairLink
        let privateKey: P256.KeyAgreement.PrivateKey
        let expiresAt: Date
    }

    let devices: PairedDevices
    private(set) var pairing: Pairing?
    /// Ids of the phones connected right now.
    private(set) var connected: Set<String> = []
    /// Why the Mac cannot listen, for the Devices tab.
    private(set) var problem: String?

    /// The timer's state, sent to a phone as soon as it connects.
    @ObservationIgnored var currentState: () -> EngineState? = { nil }
    /// A phone's state, already on this Mac's clock.
    @ObservationIgnored var onState: (EngineState) -> Void = { _ in }
    /// The interval settings and when the user last changed them, sent to a phone as soon as it connects.
    @ObservationIgnored var currentIntervals: () -> (IntervalSettings, Date)? = { nil }
    /// A phone's interval settings and their change time, already on this Mac's clock.
    @ObservationIgnored var onIntervals: (IntervalSettings, Date) -> Void = { _, _ in }

    @ObservationIgnored private var listener: NWListener?
    @ObservationIgnored private var port: UInt16?
    @ObservationIgnored private var peers: [Peer] = []
    @ObservationIgnored private var wantsPairing = false
    @ObservationIgnored private var pairingTimer: Timer?
    @ObservationIgnored private var pendingState: EngineState?
    /// The phone a pending state came from: it has that state already.
    @ObservationIgnored private var pendingSource: Peer?
    @ObservationIgnored private var receivingFrom: Peer?
    @ObservationIgnored private var lastBroadcast = Date.distantPast
    @ObservationIgnored private var sentIntervalsAt: Date?

    init(devices: PairedDevices) {
        self.devices = devices
        updateListening()
    }

    func beginPairing() {
        wantsPairing = true
        updateListening()
        if port != nil { makePairing() }
    }

    func endPairing() {
        wantsPairing = false
        pairing = nil
        pairingTimer?.invalidate()
        updateListening()
    }

    func remove(_ id: String) {
        for peer in peers where peer.deviceId == id {
            peer.connection.send(.unpair)
            peer.connection.close()
        }
        devices.remove(id: id)
        updateListening()
    }

    func broadcast(_ state: EngineState) {
        let scheduled = pendingState != nil
        // A state taken from a phone goes to the others only; a newer change
        // of the Mac's own, before the send, goes to all.
        pendingSource = scheduled && pendingSource !== receivingFrom ? nil : receivingFrom
        pendingState = state
        guard !scheduled else { return }
        let wait = max(0, lastBroadcast.addingTimeInterval(Self.sendInterval).timeIntervalSinceNow)
        DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [weak self] in
            MainActor.assumeIsolated { self?.sendPendingState() }
        }
    }

    /// After every settings change; sends only when the intervals' change time moved,
    /// which includes intervals taken from one phone and passed on to the others.
    func intervalsChanged(_ intervals: IntervalSettings, changedAt: Date) {
        guard changedAt != sentIntervalsAt else { return }
        sentIntervalsAt = changedAt
        for peer in peers where peer.isOpen {
            peer.connection.send(.intervals(intervals, changedAt: changedAt, sentAt: Date()))
        }
    }

    private func sendPendingState() {
        guard let state = pendingState else { return }
        pendingState = nil
        lastBroadcast = Date()
        for peer in peers where peer.isOpen && peer !== pendingSource {
            peer.connection.send(.state(state, sentAt: lastBroadcast))
        }
        pendingSource = nil
    }

    // MARK: - Listening

    private func updateListening() {
        let wanted = wantsPairing || !devices.list.isEmpty
        if wanted, listener == nil {
            listen(on: Self.preferredPort)
        } else if !wanted, let listener {
            listener.cancel()
            self.listener = nil
            port = nil
            peers.forEach { $0.connection.close() }
        }
    }

    private func listen(on preferred: UInt16?) {
        let parameters = NWParameters.tcp
        let port = preferred.flatMap(NWEndpoint.Port.init(rawValue:)) ?? .any
        guard let listener = try? NWListener(using: parameters, on: port) else {
            problem = "Could not open a network port."
            return
        }
        listener.service = NWListener.Service(
            type: "_pomodoro._tcp",
            txtRecord: NWTXTRecord(["id": devices.macId])
        )
        listener.stateUpdateHandler = { [weak self] state in
            MainActor.assumeIsolated { self?.listenerChanged(state, preferred: preferred) }
        }
        listener.newConnectionHandler = { [weak self] connection in
            MainActor.assumeIsolated { self?.accept(connection) }
        }
        self.listener = listener
        listener.start(queue: .main)
    }

    private func listenerChanged(_ state: NWListener.State, preferred: UInt16?) {
        switch state {
        case .ready:
            problem = nil
            port = listener?.port?.rawValue
            if wantsPairing, pairing == nil { makePairing() }
        case .failed(let error):
            listener?.cancel()
            listener = nil
            port = nil
            if preferred != nil, case .posix(.EADDRINUSE) = error {
                listen(on: nil)
            } else {
                problem = "The network is not available: \(error.localizedDescription)"
            }
        case .waiting(let error):
            problem = "Allow Pomodoro in System Settings → Privacy & Security → Local Network. (\(error.localizedDescription))"
        default:
            break
        }
    }

    private func makePairing() {
        guard let port else { return }
        let key = P256.KeyAgreement.PrivateKey()
        let link = PairLink(
            macId: devices.macId,
            publicKey: key.publicKey.x963Representation,
            token: SyncCrypto.random(16),
            addresses: Array(Self.localAddresses().prefix(4)),
            port: port
        )
        pairing = Pairing(link: link, privateKey: key, expiresAt: Date().addingTimeInterval(Self.pairingLifetime))
        #if DEBUG
        // For pairing the emulator, which has no camera to read the QR.
        print("pair link: \(link.link)")
        fflush(stdout)
        #endif
        pairingTimer?.invalidate()
        pairingTimer = Timer.scheduledTimer(withTimeInterval: Self.pairingLifetime, repeats: false) { [weak self] _ in
            // As Cancel does: with no phone paired, the Mac stops listening too.
            MainActor.assumeIsolated { self?.endPairing() }
        }
    }

    // MARK: - Connections

    private func accept(_ connection: NWConnection) {
        let peer = Peer(SyncConnection(connection, limit: Self.helloLimit))
        peers.append(peer)
        Task {
            await serve(peer)
            peer.connection.close()
            peers.removeAll { $0 === peer }
            connected = Set(peers.filter(\.isOpen).compactMap(\.deviceId))
        }
    }

    /// One phone: its plain hello, checked, then encrypted messages until either side closes.
    private func serve(_ peer: Peer) async {
        let connection = peer.connection
        do {
            try await connection.open()
            let first = try await connection.read()
            // Checking it can wait on a Keychain password prompt; that gets a minute.
            connection.settle()
            switch await handshake(first) {
            case .failure(.reason(let reason)):
                connection.send(.error(reason))
                return
            case .failure(.silent):
                return
            case .success(let phone):
                guard !connection.isClosed else { return }
                let nonce = SyncCrypto.random(16)
                connection.send(.hello(id: devices.macId, nonce: nonce, name: Self.macName, kind: DeviceKind.mac))
                connection.startSession(deviceKey: phone.key, nonceClient: phone.nonce, nonceServer: nonce, isMac: true)
                peer.deviceId = phone.id
                opened(peer)
            }
            while true {
                received(try await connection.read(), from: peer)
            }
        } catch {
            // Closed, or a frame that did not open: either way this phone is gone.
        }
    }

    /// The answer to a phone's first frame: the device key, or the error to send back.
    private func handshake(_ message: SyncMessage) async -> Result<Accepted, HandshakeError> {
        switch message {
        case .hello(let id, let nonce, _, _):
            guard devices.contains(id) else { return .failure(.reason("unknown-device")) }
            guard let key = await devices.key(for: id) else { return .failure(.reason("keychain")) }
            return .success(Accepted(id: id, key: key, nonce: nonce))
        case .pair(let id, let name, let kind, let phoneKey, let nonce, let proof):
            guard let pairing, pairing.expiresAt > Date(),
                  SyncCrypto.proofMatches(proof, token: pairing.link.token,
                                          phonePublicKey: phoneKey, macPublicKey: pairing.link.publicKey),
                  let key = try? SyncCrypto.deviceKey(privateKey: pairing.privateKey,
                                                      peerPublicKey: phoneKey, token: pairing.link.token)
            else { return .failure(.reason("pairing-expired")) }
            guard devices.add(id: id, name: name, kind: kind, key: key) else { return .failure(.reason("keychain")) }
            // One QR, one phone. After add(): with no phone paired, ending the
            // pairing would stop the listener and drop this very connection.
            endPairing()
            return .success(Accepted(id: id, key: key, nonce: nonce))
        case .unsupportedVersion:
            return .failure(.reason("version"))
        default:
            return .failure(.silent)
        }
    }

    private func opened(_ peer: Peer) {
        connected = Set(peers.filter(\.isOpen).compactMap(\.deviceId))
        if let state = currentState() { peer.connection.send(.state(state, sentAt: Date())) }
        if let (intervals, changedAt) = currentIntervals() {
            peer.connection.send(.intervals(intervals, changedAt: changedAt, sentAt: Date()))
        }
    }

    private func received(_ message: SyncMessage, from peer: Peer) {
        switch message {
        case .state(let state, let sentAt):
            receivingFrom = peer
            onState(state.shifted(by: Date().timeIntervalSince(sentAt)))
            receivingFrom = nil
        case .intervals(let intervals, let changedAt, let sentAt):
            onIntervals(intervals, SyncRules.shifted(changedAt, by: Date().timeIntervalSince(sentAt)))
        case .unpair:
            if let id = peer.deviceId { devices.remove(id: id) }
            peer.connection.close()
            updateListening()
        default:
            break
        }
    }

    // MARK: - Helpers

    /// The Mac's IPv4 addresses, for the QR: pairing then needs no discovery.
    private static func localAddresses() -> [String] {
        var first: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&first) == 0, let first else { return [] }
        defer { freeifaddrs(first) }
        var result: [String] = []
        for entry in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let flags = Int32(entry.pointee.ifa_flags)
            guard let address = entry.pointee.ifa_addr, address.pointee.sa_family == UInt8(AF_INET),
                  flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0 else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count),
                              nil, 0, NI_NUMERICHOST) == 0 else { continue }
            let text = String(decoding: host.prefix { $0 != 0 }.map(UInt8.init(bitPattern:)), as: UTF8.self)
            if !text.hasPrefix("169.254.") { result.append(text) }
        }
        return result
    }
}

/// A phone let in: its id, its device key and its hello nonce.
private struct Accepted {
    let id: String
    let key: SymmetricKey
    let nonce: Data
}

private enum HandshakeError: Error {
    /// Sent back to the phone before closing.
    case reason(String)
    /// Not a phone speaking this protocol: just close.
    case silent
}

/// One phone's connection, and which phone it is once its hello checked out.
@MainActor
private final class Peer {
    let connection: SyncConnection
    var deviceId: String?

    var isOpen: Bool { connection.isSecure }

    init(_ connection: SyncConnection) {
        self.connection = connection
    }
}
