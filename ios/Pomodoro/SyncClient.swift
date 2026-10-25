import CryptoKit
import Foundation
import Network
import Observation
import PomodoroCore
import PomodoroSync
import UIKit

/// The Mac said no before the session started. Unauthenticated, so it is
/// shown, never acted on: the pairing stays.
struct Refused: Error {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    init(reason: String) {
        switch reason {
        case "unknown-device": message = "The Mac no longer knows this iPhone. Forget it here and pair again."
        case "pairing-expired": message = "The code on the Mac has expired. Show a new one and scan again."
        case "keychain": message = "The Mac could not open this iPhone's key. Allow Pomodoro when the Mac asks for the Keychain password, then reopen the app."
        case "version": message = "Update Pomodoro on both devices."
        default: message = "The Mac refused: \(reason)"
        }
    }
}

/// The phone's side of docs/SYNC.md, as on Android: finds the paired Mac on
/// the Wi-Fi, keeps one encrypted connection to it while the app is on
/// screen, and passes timer states between it and the timer.
@MainActor
@Observable
final class SyncClient {
    enum Status: Equatable {
        case notPaired, pairing, searching, connected
        case failed(String)
    }

    private static let serviceType = "_pomodoro._tcp"
    /// Dragging the ring changes the state with every step; the Mac gets the newest this often.
    private static let sendInterval: TimeInterval = 0.1
    private static let helloLimit: TimeInterval = 5
    private static let discoveryLimit: TimeInterval = 5
    private static let quickLimit: TimeInterval = 2.5
    /// A first pairing waits for iOS to ask about the Local Network: until
    /// the user answers, every connection waits too.
    private static let pairingLimit: TimeInterval = 30

    private(set) var status: Status

    @ObservationIgnored private let store = PairedMac()
    @ObservationIgnored private let timer: PomodoroTimer
    @ObservationIgnored private var worker: Task<Void, Never>?
    /// The worker's connection, open or being opened.
    @ObservationIgnored private var link: SyncConnection?
    @ObservationIgnored private var discovered: NWEndpoint?
    /// The newest state not sent yet.
    @ObservationIgnored private var pendingState: EngineState?
    @ObservationIgnored private var lastStateSent = Date.distantPast

    init(timer: PomodoroTimer) {
        self.timer = timer
        status = store.macId == nil ? .notPaired : .searching
        timer.onStateChange = { [weak self] in self?.queue($0) }
        timer.onIntervalsChange = { [weak self] intervals, changedAt in
            self?.session?.send(.intervals(intervals, changedAt: changedAt, sentAt: Date()))
        }
    }

    /// Read with `status`: every change of this one changes the status too.
    var isPaired: Bool { store.macId != nil }

    /// "MacBook Pro (Mac)", or "the Mac" until it has said its name.
    var pairedTitle: String {
        guard let name = store.macName else { return "the Mac" }
        return "\(name) (\(DeviceKind.title(store.macKind ?? DeviceKind.mac)))"
    }

    private var session: SyncConnection? {
        guard let link, link.isSecure else { return nil }
        return link
    }

    /// True while the app is on screen: only then does the phone keep a connection.
    func setActive(_ on: Bool) {
        // A worker that gave up (a failed pairing, a refusal) starts again on the next return.
        if !on { stop() } else if isPaired, worker == nil { start(nil) }
    }

    func pair(_ link: PairLink) {
        stop()
        start(link)
    }

    func forget() {
        // The Mac forgets the phone too, if it hears this: closing lets it go out first.
        session?.send(.unpair)
        stop()
        store.forget()
        status = .notPaired
    }

    /// For the Lock Screen button while the app is closed: a short connection
    /// to the last address that worked, which sends this phone's state and
    /// takes the Mac's, in at most `quickLimit`. Nothing waits on discovery.
    func quickSync() async {
        guard session == nil, let macId = store.macId, let key = store.deviceKey(),
              let address = store.lastAddress else { return }
        let link = SyncConnection(to: address, limit: Self.quickLimit)
        defer { link.close() }
        do {
            try await link.open()
            let mac = try await hello(on: link, macId: macId, key: key)
            store.saveIdentity(name: mac.name, kind: mac.kind)
            sendCurrent(on: link)
            // The Mac sends its state right after the hello; that is all this needs.
            while true {
                let message = try await link.read()
                handle(message)
                if case .state = message { break }
            }
        } catch {
            // No Mac this time: the phone keeps its own state.
        }
    }

    private func start(_ pairing: PairLink?) {
        worker = Task { await run(pairing) }
    }

    private func stop() {
        worker?.cancel()
        worker = nil
        link?.close()
        link = nil
    }

    // MARK: - The worker

    private func run(_ pairing: PairLink?) async {
        var pairing = pairing
        let pairingUntil = Date().addingTimeInterval(Self.pairingLimit)
        var delay: TimeInterval = 1
        while !Task.isCancelled {
            setStatus(pairing == nil ? .searching : .pairing)
            do {
                let link: SyncConnection
                if let pairing {
                    link = try await pair(with: pairing)
                } else {
                    link = try await connect()
                }
                pairing = nil
                delay = 1
                setStatus(.connected)
                sendCurrent(on: link)
                while true {
                    handle(try await link.read())
                }
            } catch let refused as Refused {
                setStatus(.failed(refused.message))
                break
            } catch {
                if pairing != nil, Date() > pairingUntil {
                    setStatus(.failed("Could not reach the Mac. Check that both are on the same Wi-Fi, and that Pomodoro "
                        + "may use it: iOS Settings → Privacy & Security → Local Network."))
                    break
                }
            }
            guard !Task.isCancelled else { return }
            link?.close()
            setStatus(pairing == nil ? .searching : .pairing)
            try? await Task.sleep(for: .seconds(delay))
            // A pairing retries every second: the user may allow the Local Network any moment.
            if pairing == nil { delay = min(delay * 2, 30) }
        }
        // Gave up: setActive starts a new worker on the next return to the app.
        if !Task.isCancelled {
            link?.close()
            link = nil
            worker = nil
        }
    }

    private func pair(with pairing: PairLink) async throws -> SyncConnection {
        guard let port = NWEndpoint.Port(rawValue: pairing.port) else { throw SyncConnection.Failure.closed }
        var opened: SyncConnection?
        for address in pairing.addresses {
            if let link = try? await open(.hostPort(host: NWEndpoint.Host(address), port: port)) {
                opened = link
                break
            }
            try Task.checkCancellation()
        }
        guard let link = opened else { throw SyncConnection.Failure.closed }

        let privateKey = P256.KeyAgreement.PrivateKey()
        let phoneKey = privateKey.publicKey.x963Representation
        let deviceKey = try SyncCrypto.deviceKey(privateKey: privateKey, peerPublicKey: pairing.publicKey, token: pairing.token)
        let nonce = SyncCrypto.random(16)
        let proof = SyncCrypto.proof(token: pairing.token, phonePublicKey: phoneKey, macPublicKey: pairing.publicKey)
        link.send(.pair(id: store.phoneId, name: Self.deviceName, kind: DeviceKind.ios,
                        publicKey: phoneKey, nonce: nonce, proof: proof))
        let mac = try await macHello(on: link, macId: pairing.macId, key: deviceKey, nonce: nonce)
        link.settle()
        // Only the Mac that showed the QR can derive the key: a first frame
        // that decrypts proves it is that Mac. Store the key only then.
        let first = try await link.read()
        guard store.save(macId: pairing.macId, key: deviceKey) else {
            throw Refused("This iPhone could not save the key in its Keychain. Pair again.")
        }
        store.saveAddress(link.remote)
        store.saveIdentity(name: mac.name, kind: mac.kind)
        handle(first)
        return link
    }

    /// Tries each address until one answers the hello: an address can take
    /// the connection and still say nothing (a Mac waiting on its Local
    /// Network permission, an old address now someone else's).
    private func connect() async throws -> SyncConnection {
        guard let macId = store.macId else { throw CancellationError() }
        guard let key = store.deviceKey() else {
            throw Refused("This iPhone lost its key. Forget the Mac and pair again.")
        }
        var targets: [NWEndpoint] = []
        if let found = await discover(macId) { targets.append(found) }
        if let last = store.lastAddress { targets.append(last) }
        for target in targets {
            guard let link = try? await open(target) else {
                try Task.checkCancellation()
                continue
            }
            do {
                let mac = try await hello(on: link, macId: macId, key: key)
                link.settle()
                store.saveAddress(link.remote)
                store.saveIdentity(name: mac.name, kind: mac.kind)
                return link
            } catch let refused as Refused {
                throw refused
            } catch {
                link.close()
                try Task.checkCancellation()
            }
        }
        throw SyncConnection.Failure.closed
    }

    private func open(_ target: NWEndpoint) async throws -> SyncConnection {
        // A stopped worker must not take over the connection of the one after it.
        try Task.checkCancellation()
        let link = SyncConnection(to: target, limit: Self.helloLimit)
        self.link = link
        try await link.open()
        return link
    }

    private func hello(on link: SyncConnection, macId: String, key: SymmetricKey) async throws -> (name: String, kind: String) {
        let nonce = SyncCrypto.random(16)
        link.send(.hello(id: store.phoneId, nonce: nonce, name: Self.deviceName, kind: DeviceKind.ios))
        return try await macHello(on: link, macId: macId, key: key, nonce: nonce)
    }

    /// The Mac's hello, checked to come from the expected Mac, then the session keys.
    private func macHello(on link: SyncConnection, macId: String, key: SymmetricKey,
                          nonce: Data) async throws -> (name: String, kind: String) {
        switch try await link.read() {
        case .hello(let id, let nonceServer, let name, let kind):
            guard id == macId else { throw SyncConnection.Failure.unexpected }
            link.startSession(deviceKey: key, nonceClient: nonce, nonceServer: nonceServer, isMac: false)
            return (name, kind)
        case .error(let reason):
            throw Refused(reason: reason)
        default:
            throw SyncConnection.Failure.unexpected
        }
    }

    /// The Mac's Bonjour service, or nil within a few seconds.
    private func discover(_ macId: String) async -> NWEndpoint? {
        discovered = nil
        let browser = NWBrowser(for: .bonjourWithTXTRecord(type: Self.serviceType, domain: nil), using: .tcp)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            MainActor.assumeIsolated {
                self?.discovered = results.first { result in
                    guard case .bonjour(let txt) = result.metadata else { return false }
                    return txt["id"] == macId
                }?.endpoint
            }
        }
        browser.start(queue: .main)
        defer { browser.cancel() }
        let deadline = Date().addingTimeInterval(Self.discoveryLimit)
        while discovered == nil, Date() < deadline, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(100))
        }
        return discovered
    }

    // MARK: - Messages

    private func sendCurrent(on link: SyncConnection) {
        let settings = timer.settings
        link.send(.state(timer.state, sentAt: Date()))
        link.send(.intervals(settings.intervals, changedAt: settings.intervalsChangedAt, sentAt: Date()))
    }

    private func queue(_ state: EngineState) {
        let scheduled = pendingState != nil
        pendingState = state
        guard !scheduled else { return }
        let wait = max(0, lastStateSent.addingTimeInterval(Self.sendInterval).timeIntervalSinceNow)
        Task {
            try? await Task.sleep(for: .seconds(wait))
            guard let newest = pendingState else { return }
            pendingState = nil
            lastStateSent = Date()
            session?.send(.state(newest, sentAt: lastStateSent))
        }
    }

    private func handle(_ message: SyncMessage) {
        let now = Date()
        switch message {
        case .state(let state, let sentAt):
            timer.receive(state.shifted(by: now.timeIntervalSince(sentAt)))
        case .intervals(let intervals, let changedAt, let sentAt):
            timer.receiveIntervals(intervals, changedAt: SyncRules.shifted(changedAt, by: now.timeIntervalSince(sentAt)))
        case .unpair:
            stop()
            store.forget()
            status = .notPaired
        default:
            break
        }
    }

    /// A late status from a stopped worker must not override "not paired".
    private func setStatus(_ new: Status) {
        guard !Task.isCancelled else { return }
        status = new
    }

    private static var deviceName: String { UIDevice.current.name }
}
