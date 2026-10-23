package com.nikolaev.pomodoro.sync

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.os.Build
import android.os.Handler
import android.os.Looper
import com.nikolaev.pomodoro.TimerRepository
import com.nikolaev.pomodoro.core.DeviceKind
import com.nikolaev.pomodoro.core.EngineState
import com.nikolaev.pomodoro.core.Frames
import com.nikolaev.pomodoro.core.PairLink
import com.nikolaev.pomodoro.core.SessionCipher
import com.nikolaev.pomodoro.core.SyncCrypto
import com.nikolaev.pomodoro.core.SyncMessage
import com.nikolaev.pomodoro.core.SyncRules
import com.nikolaev.pomodoro.core.shifted
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.io.BufferedInputStream
import java.io.DataInputStream
import java.io.IOException
import java.net.InetSocketAddress
import java.net.Socket
import java.security.interfaces.ECPublicKey
import java.util.concurrent.CompletableFuture
import java.util.concurrent.Executors
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

/**
 * The phone's side of docs/SYNC.md: finds the paired Mac on the Wi-Fi, keeps
 * one encrypted connection to it while the app is open, and passes timer
 * states between it and the timer. Everything public is called on the main
 * thread; the connection lives on its own thread.
 */
class SyncClient(context: Context, private val timer: TimerRepository) {
    sealed interface Status {
        data object NotPaired : Status
        data object Pairing : Status
        data object Searching : Status
        data object Connected : Status
        data class Failed(val message: String) : Status
    }

    private val store = PairedMac(context)
    private val nsd = context.getSystemService(NsdManager::class.java)
    private val main = Handler(Looper.getMainLooper())
    private val writer = Executors.newSingleThreadScheduledExecutor()

    private val _status = MutableStateFlow<Status>(if (store.macId == null) Status.NotPaired else Status.Searching)
    val status: StateFlow<Status> = _status.asStateFlow()

    /** Read with [status]: every change of this one changes the status too. */
    val isPaired: Boolean get() = store.macId != null

    /** "MacBook Pro (Mac)", or "the Mac" until it has said its name. */
    val pairedTitle: String get() {
        val name = store.macName ?: return "the Mac"
        return "$name (${DeviceKind.title(store.macKind ?: DeviceKind.MAC)})"
    }

    private var worker: Thread? = null
    @Volatile private var connection: Connection? = null
    /** The newest state not sent yet: dragging the ring changes it with every step. */
    private val pendingState = AtomicReference<EngineState?>(null)
    @Volatile private var lastStateSent = 0.0

    init {
        timer.onStateChange = { state ->
            if (pendingState.getAndSet(state) == null) {
                val wait = ((lastStateSent + SEND_INTERVAL - now()) * 1000).toLong().coerceAtLeast(0)
                writer.schedule({
                    val newest = pendingState.getAndSet(null) ?: return@schedule
                    lastStateSent = now()
                    connection?.trySend(SyncMessage.State(newest, lastStateSent))
                }, wait, TimeUnit.MILLISECONDS)
            }
        }
        timer.onIntervalsChange = { intervals, changedAt ->
            connection?.let { c -> writer.execute { c.trySend(SyncMessage.Intervals(intervals, changedAt, now())) } }
        }
        writer.scheduleWithFixedDelay({
            connection?.takeIf { now() - it.lastSent > PING_AFTER }?.trySend(SyncMessage.Ping)
        }, 5, 5, TimeUnit.SECONDS)
    }

    /** True while the app is on screen: only then does the phone keep a connection. */
    fun setActive(on: Boolean) {
        // A worker that gave up (a failed pairing, a refusal) is started again on the next return.
        if (!on) stop() else if (store.macId != null && worker?.isAlive != true) start(null)
    }

    fun pair(link: PairLink) {
        stop()
        start(link)
    }

    fun forget() {
        // The Mac forgets the phone too, if it hears this: the writer sends and
        // then closes, so the worker is only told to stop, not cut off first.
        val c = connection
        worker?.interrupt()
        worker = null
        writer.execute {
            c?.trySend(SyncMessage.Unpair)
            c?.close()
        }
        store.forget()
        _status.value = Status.NotPaired
    }

    private fun start(pairing: PairLink?) {
        worker = Thread({ run(pairing) }, "sync").apply { start() }
    }

    /** Atomic with the hand-over in [open]: a worker either sees the interrupt or has its socket closed here. */
    @Synchronized
    private fun stop() {
        worker?.interrupt()
        worker = null
        connection?.close()
    }

    // Everything below runs on the worker thread, except where it posts to `main`.

    private fun run(pairing: PairLink?) {
        var link = pairing
        var delay = 1_000L
        while (!Thread.currentThread().isInterrupted) {
            setStatus(if (link != null) Status.Pairing else Status.Searching)
            var c: Connection? = null
            try {
                c = if (link != null) pairWith(link) else connect() ?: throw IOException("not found")
                link = null
                delay = 1_000L
                setStatus(Status.Connected)
                c.trySend(SyncMessage.State(timer.state.value, now()))
                val settings = timer.settings.value
                c.trySend(SyncMessage.Intervals(settings.intervals, settings.intervalsChangedAt, now()))
                while (true) {
                    val message = c.read()
                    val receivedAt = now()
                    main.post { handle(message, receivedAt) }
                }
            } catch (refused: Refused) {
                setStatus(Status.Failed(refused.message ?: ""))
                return
            } catch (_: Exception) {
                if (link != null) {
                    setStatus(Status.Failed("Could not reach the Mac. Check that both are on the same Wi-Fi."))
                    return
                }
            } finally {
                // Only its own: after pair(), a new worker may already have one.
                c?.close()
                if (connection === c) connection = null
            }
            if (Thread.currentThread().isInterrupted) return
            setStatus(Status.Searching)
            try {
                Thread.sleep(delay)
            } catch (_: InterruptedException) {
                return
            }
            delay = (delay * 2).coerceAtMost(30_000L)
        }
    }

    private fun pairWith(link: PairLink): Connection {
        val c = open(link.addresses.map { it to link.port }) ?: throw IOException("not reachable")
        val keys = SyncCrypto.newKeyPair()
        val phoneKey = SyncCrypto.encode(keys.public as ECPublicKey)
        val deviceKey = SyncCrypto.deviceKey(keys.private, link.publicKey, link.token)
        val nonce = PairedMac.randomBytes(16)
        val proof = SyncCrypto.proof(link.token, phoneKey, link.publicKey)
        c.trySend(SyncMessage.Pair(store.phoneId, Build.MODEL, DeviceKind.ANDROID, phoneKey, nonce, proof))
        val mac = c.startSession(link.macId, deviceKey, nonce)
        // Only the Mac that showed the QR can derive the key: a first frame
        // that decrypts proves it is that Mac. Store the key only then.
        val first = c.read()
        store.save(link.macId, deviceKey, c.host, c.port)
        store.saveIdentity(mac.name, mac.kind)
        val receivedAt = now()
        main.post { handle(first, receivedAt) }
        return c
    }

    private fun connect(): Connection? {
        val macId = store.macId ?: return null
        val key = store.deviceKey() ?: throw Refused("This phone lost its key. Forget the Mac and pair again.")
        val c = open(listOfNotNull(discover(macId), store.lastAddress).distinct()) ?: return null
        val nonce = PairedMac.randomBytes(16)
        c.trySend(SyncMessage.Hello(store.phoneId, nonce, Build.MODEL, DeviceKind.ANDROID))
        val mac = c.startSession(macId, key, nonce)
        store.saveAddress(c.host, c.port)
        store.saveIdentity(mac.name, mac.kind)
        return c
    }

    private fun open(targets: List<Pair<String, Int>>): Connection? {
        for ((host, port) in targets) {
            if (Thread.currentThread().isInterrupted) return null
            try {
                val socket = Socket().apply {
                    connect(InetSocketAddress(host, port), 3_000)
                    soTimeout = (SILENCE_LIMIT * 1000).toInt()
                }
                // A connect cannot be interrupted: a worker stopped during it must not take over.
                synchronized(this) {
                    if (Thread.currentThread().isInterrupted) {
                        socket.close()
                        return null
                    }
                    return Connection(socket, host, port).also { connection = it }
                }
            } catch (_: IOException) {
                // Try the next address.
            }
        }
        return null
    }

    /** The Mac's address from Bonjour, or null within a few seconds. */
    @Suppress("DEPRECATION") // resolveService and host: their replacements need Android 14.
    private fun discover(macId: String): Pair<String, Int>? {
        val found = LinkedBlockingQueue<NsdServiceInfo>()
        val listener = object : NsdManager.DiscoveryListener {
            override fun onServiceFound(info: NsdServiceInfo) {
                found.offer(info)
            }
            override fun onServiceLost(info: NsdServiceInfo) = Unit
            override fun onDiscoveryStarted(type: String) = Unit
            override fun onDiscoveryStopped(type: String) = Unit
            override fun onStartDiscoveryFailed(type: String, code: Int) = Unit
            override fun onStopDiscoveryFailed(type: String, code: Int) = Unit
        }
        nsd.discoverServices(SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, listener)
        try {
            val deadline = System.currentTimeMillis() + 5_000
            while (true) {
                val info = found.poll(deadline - System.currentTimeMillis(), TimeUnit.MILLISECONDS) ?: return null
                val resolved = CompletableFuture<NsdServiceInfo?>()
                nsd.resolveService(info, object : NsdManager.ResolveListener {
                    override fun onServiceResolved(info: NsdServiceInfo) {
                        resolved.complete(info)
                    }
                    override fun onResolveFailed(info: NsdServiceInfo, code: Int) {
                        resolved.complete(null)
                    }
                })
                val service = try {
                    resolved.get(3, TimeUnit.SECONDS)
                } catch (_: java.util.concurrent.TimeoutException) {
                    null
                } ?: continue
                if (service.attributes["id"]?.decodeToString() == macId) {
                    return (service.host?.hostAddress ?: continue) to service.port
                }
            }
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
            return null
        } finally {
            runCatching { nsd.stopServiceDiscovery(listener) }
        }
    }

    private fun setStatus(status: Status) = main.post {
        // A late post from a stopped worker must not override "not paired".
        if (store.macId != null || status !is Status.Searching) _status.value = status
    }

    /** On the main thread. */
    private fun handle(message: SyncMessage, receivedAt: Double) {
        when (message) {
            is SyncMessage.State -> timer.receive(message.state.shifted(receivedAt - message.sentAt))
            is SyncMessage.Intervals ->
                timer.receiveIntervals(message.intervals, SyncRules.shifted(message.changedAt, receivedAt - message.sentAt))
            SyncMessage.Unpair -> {
                store.forget()
                stop()
                _status.value = Status.NotPaired
            }
            else -> Unit
        }
    }

    private class Refused(message: String) : Exception(message)

    /** One TCP connection: plain hellos, then encrypted frames. */
    private class Connection(private val socket: Socket, val host: String, val port: Int) {
        private val input = DataInputStream(BufferedInputStream(socket.getInputStream()))
        private val output = socket.getOutputStream()
        @Volatile private var cipher: SessionCipher? = null
        @Volatile var lastSent = now()

        /** The Mac's hello, checked to come from the expected Mac, then the session keys. */
        fun startSession(macId: String, deviceKey: ByteArray, nonceClient: ByteArray): SyncMessage.Hello {
            when (val reply = read()) {
                is SyncMessage.Hello -> {
                    if (reply.id != macId) throw IOException("another Mac")
                    val (c2s, s2c) = SyncCrypto.sessionKeys(deviceKey, nonceClient, reply.nonce)
                    cipher = SessionCipher(sendKey = c2s, receiveKey = s2c)
                    return reply
                }
                is SyncMessage.Error -> throw Refused(
                    when (reply.reason) {
                        "unknown-device" -> "The Mac no longer knows this phone. Forget it here and pair again."
                        "pairing-expired" -> "The code on the Mac has expired. Show a new one and scan again."
                        "keychain" -> "The Mac could not open this phone's key. Allow Pomodoro when the Mac asks for the Keychain password, then reopen the app."
                        "version" -> "Update Pomodoro on both devices."
                        else -> "The Mac refused: ${reply.reason}"
                    },
                )
                else -> throw IOException("unexpected reply")
            }
        }

        fun read(): SyncMessage {
            val length = input.readInt()
            Frames.checkLength(length)
            val frame = ByteArray(length).also(input::readFully)
            val payload = cipher?.open(frame) ?: frame
            return SyncMessage.decode(payload) ?: throw IOException("bad message")
        }

        /** Any thread. A failed write closes the connection; the reader then reconnects. */
        @Synchronized
        fun trySend(message: SyncMessage) {
            try {
                val bytes = message.encode()
                output.write(Frames.frame(cipher?.seal(bytes) ?: bytes))
                output.flush()
                lastSent = now()
            } catch (_: Exception) {
                close()
            }
        }

        fun close() {
            runCatching { socket.close() }
        }
    }

    private companion object {
        const val SERVICE_TYPE = "_pomodoro._tcp"
        const val PING_AFTER = 20.0
        const val SEND_INTERVAL = 0.1
        const val SILENCE_LIMIT = 60.0

        fun now(): Double = System.currentTimeMillis() / 1000.0
    }
}
