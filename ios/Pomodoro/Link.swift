import CryptoKit
import Foundation
import Network
import PomodoroCore

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

/// One TCP connection to the Mac: the plain hellos, then encrypted frames
/// (docs/SYNC.md). It closes itself on silence longer than `limit`, on a bad
/// frame, and when the task waiting on it is cancelled.
@MainActor
final class Link {
    enum Failure: Error { case closed, wrongMac, unexpected }

    private static let pingAfter: TimeInterval = 20
    private static let silenceLimit: TimeInterval = 60

    private let connection: NWConnection
    private var reader = FrameReader()
    private var frames: [Data] = []
    private var cipher: SessionCipher?
    private var waiter: CheckedContinuation<Void, Never>?
    private var watchdog: Timer?
    /// Until the hello: the time to connect and hear it. Then the silence allowed.
    private var limit: TimeInterval
    private var settled = false
    private var isReady = false
    private var lastSent = Date()
    private var lastReceived = Date()
    private(set) var isClosed = false

    /// The session keys are in place: from here on everything is encrypted.
    var isSecure: Bool { cipher != nil && !isClosed }
    var remote: NWEndpoint? { connection.currentPath?.remoteEndpoint }

    init(to endpoint: NWEndpoint, limit: TimeInterval) {
        connection = NWConnection(to: endpoint, using: .tcp)
        self.limit = limit
    }

    func open() async throws {
        connection.stateUpdateHandler = { [weak self] state in
            MainActor.assumeIsolated {
                guard let self else { return }
                switch state {
                case .ready:
                    self.isReady = true
                    self.wake()
                // Waiting means no route, a refused port or no Local Network
                // permission: the caller tries the next address instead.
                case .waiting, .failed, .cancelled:
                    self.close()
                default:
                    break
                }
            }
        }
        connection.start(queue: .main)
        watchdog = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
        receive()
        while !isReady {
            guard !isClosed else { throw Failure.closed }
            await wait()
        }
    }

    /// The Mac's hello, checked to come from the expected Mac, then the session keys.
    func startSession(macId: String, key: SymmetricKey, nonce: Data) async throws -> (name: String, kind: String) {
        switch try await read() {
        case .hello(let id, let nonceServer, let name, let kind):
            guard id == macId else { throw Failure.wrongMac }
            let keys = SyncCrypto.sessionKeys(deviceKey: key, nonceClient: nonce, nonceServer: nonceServer)
            cipher = SessionCipher(sendKey: keys.c2s, receiveKey: keys.s2c)
            return (name, kind)
        case .error(let reason):
            throw Refused(reason: reason)
        default:
            throw Failure.unexpected
        }
    }

    /// After the hello: from now on only a minute of silence means a lost connection.
    func settle() {
        settled = true
        limit = Self.silenceLimit
    }

    func read() async throws -> SyncMessage {
        while true {
            // Frames that came before a close are still read: an error, an unpair.
            if !frames.isEmpty {
                let frame = frames.removeFirst()
                do {
                    let payload = try cipher?.open(frame) ?? frame
                    guard let message = SyncMessage(data: payload) else { throw SyncCrypto.Failure.badFrame }
                    return message
                } catch {
                    close()
                    throw error
                }
            }
            guard !isClosed else { throw Failure.closed }
            await wait()
        }
    }

    func send(_ message: SyncMessage) {
        guard !isClosed else { return }
        let payload: Data
        do {
            payload = try cipher?.seal(message.data) ?? message.data
        } catch {
            return close()
        }
        lastSent = Date()
        connection.send(content: FrameReader.frame(payload), completion: .contentProcessed { [weak self] error in
            guard error != nil else { return }
            MainActor.assumeIsolated { self?.close() }
        })
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        watchdog?.invalidate()
        if isReady {
            // Lets a last frame (an unpair) go out first.
            connection.send(content: nil, contentContext: .finalMessage, isComplete: true,
                            completion: .contentProcessed { [connection] _ in connection.cancel() })
        } else {
            // Never connected: a last frame would wait for that, and the connection with it, for good.
            connection.cancel()
        }
        wake()
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            MainActor.assumeIsolated {
                guard let self, !self.isClosed else { return }
                if let data, !data.isEmpty {
                    self.lastReceived = Date()
                    self.reader.append(data)
                    do {
                        while let frame = try self.reader.next() { self.frames.append(frame) }
                    } catch {
                        return self.close()
                    }
                    self.wake()
                }
                if isComplete || error != nil { self.close() } else { self.receive() }
            }
        }
    }

    private func check() {
        let now = Date()
        if now.timeIntervalSince(lastReceived) > limit { return close() }
        if settled, isSecure, now.timeIntervalSince(lastSent) > Self.pingAfter { send(.ping) }
    }

    private func wait() async {
        await withTaskCancellationHandler {
            await withCheckedContinuation { waiter = $0 }
        } onCancel: { [weak self] in
            Task { @MainActor in self?.close() }
        }
    }

    private func wake() {
        let waiting = waiter
        waiter = nil
        waiting?.resume()
    }
}
