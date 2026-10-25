import CryptoKit
import Foundation
import Network
import PomodoroCore

/// One TCP connection of docs/SYNC.md, the Mac's end or the phone's: frames,
/// plain for the hellos, then encrypted with the session keys. It pings after
/// 20 s of quiet, and closes on a bad frame, on an error, on silence longer
/// than its limit, and when the task waiting on it is cancelled.
@MainActor
public final class SyncConnection {
    public enum Failure: Error { case closed, unexpected }

    private static let pingAfter: TimeInterval = 20
    private static let silenceLimit: TimeInterval = 60

    private let connection: NWConnection
    private var reader = FrameReader()
    private var frames: [Data] = []
    private var cipher: SessionCipher?
    private var waiter: CheckedContinuation<Void, Never>?
    private var watchdog: Timer?
    /// Until `settle()`: the time to connect and hear a hello. Then the silence allowed.
    private var limit: TimeInterval
    private var isReady = false
    private var lastSent = Date()
    private var lastReceived = Date()
    public private(set) var isClosed = false

    /// The session keys are in place: from here on everything is encrypted.
    public var isSecure: Bool { cipher != nil && !isClosed }
    public var remote: NWEndpoint? { connection.currentPath?.remoteEndpoint }

    public init(_ connection: NWConnection, limit: TimeInterval) {
        self.connection = connection
        self.limit = limit
    }

    public convenience init(to endpoint: NWEndpoint, limit: TimeInterval) {
        self.init(NWConnection(to: endpoint, using: .tcp), limit: limit)
    }

    public func open() async throws {
        connection.stateUpdateHandler = { [weak self] state in
            MainActor.assumeIsolated {
                guard let self else { return }
                switch state {
                case .ready:
                    self.isReady = true
                    self.wake()
                // Waiting means no route, a refused port or no Local Network
                // permission: the phone tries the next address instead.
                case .waiting, .failed, .cancelled:
                    self.close()
                default:
                    break
                }
            }
        }
        connection.start(queue: .main)
        startWatchdog()
        receive()
        while !isReady {
            guard !isClosed else { throw Failure.closed }
            await wait()
        }
    }

    /// After the hellos: everything from here on is encrypted.
    public func startSession(deviceKey: SymmetricKey, nonceClient: Data, nonceServer: Data, isMac: Bool) {
        let keys = SyncCrypto.sessionKeys(deviceKey: deviceKey, nonceClient: nonceClient, nonceServer: nonceServer)
        cipher = isMac
            ? SessionCipher(sendKey: keys.s2c, receiveKey: keys.c2s)
            : SessionCipher(sendKey: keys.c2s, receiveKey: keys.s2c)
    }

    /// The other side spoke: from now on only a minute of silence means a lost connection.
    public func settle() {
        limit = Self.silenceLimit
        startWatchdog()
    }

    /// The next message. Frames that came before a close are still read: an error, an unpair.
    public func read() async throws -> SyncMessage {
        while frames.isEmpty {
            guard !isClosed else { throw Failure.closed }
            await wait()
        }
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

    public func send(_ message: SyncMessage) {
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

    public func close() {
        guard !isClosed else { return }
        isClosed = true
        watchdog?.invalidate()
        if isReady {
            // Lets a last frame (an error, an unpair) go out first.
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

    private func startWatchdog() {
        watchdog?.invalidate()
        guard !isClosed else { return }
        // Ten looks within the limit, and one at least every 5 s for the ping.
        watchdog = Timer.scheduledTimer(withTimeInterval: min(limit / 10, 5), repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
    }

    private func check() {
        let now = Date()
        if now.timeIntervalSince(lastReceived) > limit { return close() }
        if isSecure, now.timeIntervalSince(lastSent) > Self.pingAfter { send(.ping) }
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
