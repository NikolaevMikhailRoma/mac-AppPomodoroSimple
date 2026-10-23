import CryptoKit
import Foundation
import Network
import Observation
import PomodoroCore

/// The Mac's side of docs/SYNC.md: listens for paired phones, runs the
/// pairing QR, and passes timer states between the phones and the timer.
/// It listens only while there is a paired phone or a QR on screen.
@MainActor
@Observable
final class SyncServer {
    static let preferredPort: UInt16 = 52025
    static let pairingLifetime: TimeInterval = 120
    /// Dragging the ring changes the state with every mouse move; phones get the newest this often.
    static let sendInterval: TimeInterval = 0.25

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

    @ObservationIgnored private var listener: NWListener?
    @ObservationIgnored private var port: UInt16?
    @ObservationIgnored private var peers: [Peer] = []
    @ObservationIgnored private var wantsPairing = false
    @ObservationIgnored private var pairingTimer: Timer?
    @ObservationIgnored private var pendingState: EngineState?
    @ObservationIgnored private var lastBroadcast = Date.distantPast

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
            peer.send(.unpair)
            peer.close()
        }
        devices.remove(id: id)
        updateListening()
    }

    func broadcast(_ state: EngineState) {
        let scheduled = pendingState != nil
        pendingState = state
        guard !scheduled else { return }
        let wait = max(0, lastBroadcast.addingTimeInterval(Self.sendInterval).timeIntervalSinceNow)
        DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [weak self] in
            MainActor.assumeIsolated { self?.sendPendingState() }
        }
    }

    private func sendPendingState() {
        guard let state = pendingState else { return }
        pendingState = nil
        lastBroadcast = Date()
        for peer in peers where peer.isOpen {
            peer.send(.state(state, sentAt: lastBroadcast))
        }
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
            peers.forEach { $0.close() }
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
            token: Self.random(16),
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
        let peer = Peer(connection: connection, server: self)
        peers.append(peer)
        peer.start()
    }

    /// The answer to a phone's first frame: the device key, or the error to send back.
    fileprivate func handshake(_ message: SyncMessage) -> Result<Accepted, HandshakeError> {
        switch message {
        case .hello(let id, let nonce):
            guard let key = devices.key(for: id) else { return .failure(.reason("unknown-device")) }
            return .success(Accepted(id: id, key: key, nonce: nonce))
        case .pair(let id, let name, let phoneKey, let nonce, let proof):
            guard let pairing, pairing.expiresAt > Date(),
                  SyncCrypto.proofMatches(proof, token: pairing.link.token,
                                          phonePublicKey: phoneKey, macPublicKey: pairing.link.publicKey),
                  let key = try? SyncCrypto.deviceKey(privateKey: pairing.privateKey,
                                                      peerPublicKey: phoneKey, token: pairing.link.token)
            else { return .failure(.reason("pairing-expired")) }
            guard devices.add(id: id, name: name, key: key) else { return .failure(.reason("keychain")) }
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

    fileprivate func opened(_ peer: Peer) {
        connected = Set(peers.filter(\.isOpen).compactMap(\.deviceId))
        if let state = currentState() { peer.send(.state(state, sentAt: Date())) }
    }

    fileprivate func received(_ message: SyncMessage, from peer: Peer) {
        switch message {
        case .state(let state, let sentAt):
            onState(state.shifted(by: Date().timeIntervalSince(sentAt)))
        case .unpair:
            if let id = peer.deviceId { devices.remove(id: id) }
            peer.close()
            updateListening()
        default:
            break
        }
    }

    fileprivate func closed(_ peer: Peer) {
        peers.removeAll { $0 === peer }
        connected = Set(peers.filter(\.isOpen).compactMap(\.deviceId))
    }

    // MARK: - Helpers

    fileprivate static func random(_ count: Int) -> Data {
        SymmetricKey(size: SymmetricKeySize(bitCount: count * 8)).withUnsafeBytes { Data($0) }
    }

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
fileprivate struct Accepted {
    let id: String
    let key: SymmetricKey
    let nonce: Data
}

fileprivate enum HandshakeError: Error {
    /// Sent back to the phone before closing.
    case reason(String)
    /// Not a phone speaking this protocol: just close.
    case silent
}

/// One phone's connection: the plain hello, then encrypted frames.
@MainActor
private final class Peer {
    private static let pingAfter: TimeInterval = 20
    private static let silenceLimit: TimeInterval = 60
    private static let handshakeLimit: TimeInterval = 10

    let connection: NWConnection
    weak var server: SyncServer?
    private(set) var deviceId: String?
    private var cipher: SessionCipher?
    private var reader = FrameReader()
    private var lastSent = Date()
    private var lastReceived = Date()
    private var watchdog: Timer?
    private var isClosed = false

    var isOpen: Bool { cipher != nil && !isClosed }

    init(connection: NWConnection, server: SyncServer) {
        self.connection = connection
        self.server = server
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            MainActor.assumeIsolated {
                switch state {
                case .failed, .cancelled: self?.close()
                default: break
                }
            }
        }
        connection.start(queue: .main)
        watchdog = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkTimers() }
        }
        receive()
    }

    func send(_ message: SyncMessage) {
        guard !isClosed else { return }
        let payload: Data
        if cipher != nil {
            guard let sealed = try? cipher!.seal(message.data) else { return close() }
            payload = sealed
        } else {
            payload = message.data
        }
        lastSent = Date()
        connection.send(content: FrameReader.frame(payload), completion: .contentProcessed { _ in })
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        watchdog?.invalidate()
        // Lets a last frame (an error, an unpair) go out first.
        connection.send(content: nil, contentContext: .finalMessage, isComplete: true,
                        completion: .contentProcessed { [connection] _ in connection.cancel() })
        server?.closed(self)
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            MainActor.assumeIsolated {
                guard let self, !self.isClosed else { return }
                if let data, !data.isEmpty {
                    self.reader.append(data)
                    self.drain()
                }
                if isComplete || error != nil { self.close() } else if !self.isClosed { self.receive() }
            }
        }
    }

    private func drain() {
        do {
            while !isClosed, let frame = try reader.next() {
                lastReceived = Date()
                try handle(frame)
            }
        } catch {
            close()
        }
    }

    private func handle(_ frame: Data) throws {
        guard cipher != nil else { return try handshake(frame) }
        let plaintext = try cipher!.open(frame)
        guard let message = SyncMessage(data: plaintext) else { throw SyncCrypto.Failure.badFrame }
        server?.received(message, from: self)
    }

    private func handshake(_ frame: Data) throws {
        guard let server, let message = SyncMessage(data: frame) else { throw SyncCrypto.Failure.badFrame }
        switch server.handshake(message) {
        case .failure(.reason(let reason)):
            send(.error(reason))
            close()
        case .failure(.silent):
            close()
        case .success(let phone):
            let nonceServer = SyncServer.random(16)
            send(.hello(id: server.devices.macId, nonce: nonceServer))
            let keys = SyncCrypto.sessionKeys(deviceKey: phone.key, nonceClient: phone.nonce, nonceServer: nonceServer)
            cipher = SessionCipher(sendKey: keys.s2c, receiveKey: keys.c2s)
            deviceId = phone.id
            server.opened(self)
        }
    }

    private func checkTimers() {
        let now = Date()
        if cipher == nil, now.timeIntervalSince(lastReceived) > Self.handshakeLimit { return close() }
        if now.timeIntervalSince(lastReceived) > Self.silenceLimit { return close() }
        if isOpen, now.timeIntervalSince(lastSent) > Self.pingAfter { send(.ping) }
    }
}
