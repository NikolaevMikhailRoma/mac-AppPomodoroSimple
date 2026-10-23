package com.nikolaev.pomodoro.core

import org.json.JSONObject
import java.net.URI
import java.time.LocalDate
import java.util.Base64

// What the Mac and the phone send each other, and how they merge it; the
// counterpart of SyncWire.swift. The protocol is docs/SYNC.md, and
// docs/sync-vectors.json pins every detail.

const val SYNC_VERSION = 1

sealed interface SyncMessage {
    // Plain classes: a data class would compare byte arrays by identity.
    class Hello(val id: String, val nonce: ByteArray) : SyncMessage
    class Pair(val id: String, val name: String, val publicKey: ByteArray, val nonce: ByteArray, val proof: ByteArray) :
        SyncMessage
    data class Error(val reason: String) : SyncMessage
    data class State(val state: EngineState, val sentAt: Double) : SyncMessage
    data object Unpair : SyncMessage
    data object Ping : SyncMessage
    /** A hello from another protocol version. */
    data object UnsupportedVersion : SyncMessage
    /** A type this version does not know: ignored. */
    data object Unknown : SyncMessage

    fun toJson(): JSONObject = when (this) {
        is Hello -> JSONObject().put("type", "hello").put("v", SYNC_VERSION).put("id", id).put("nonce", nonce.base64Url())
        is Pair -> JSONObject().put("type", "pair").put("v", SYNC_VERSION).put("id", id).put("name", name)
            .put("pub", publicKey.base64Url()).put("nonce", nonce.base64Url()).put("proof", proof.base64Url())
        is Error -> JSONObject().put("type", "error").put("reason", reason)
        is State -> JSONObject().put("type", "state").put("sentAt", sentAt).put("state", state.toWire())
        Unpair -> JSONObject().put("type", "unpair")
        Ping, UnsupportedVersion, Unknown -> JSONObject().put("type", "ping")
    }

    fun encode(): ByteArray = toJson().toString().toByteArray()

    companion object {
        /** Null when the frame is not a JSON object or a known type lacks a field. */
        fun decode(bytes: ByteArray): SyncMessage? {
            val o = parseObject(bytes.decodeToString()) ?: return null
            return when (o.str("type", "")) {
                "hello", "pair" -> {
                    if (o.int("v", 0) != SYNC_VERSION) return UnsupportedVersion
                    val id = o.str("id", "").ifEmpty { return null }
                    val nonce = o.bytes("nonce")?.takeIf { it.size == 16 } ?: return null
                    if (o.str("type", "") == "hello") return Hello(id, nonce)
                    Pair(id, o.str("name", ""), o.bytes("pub") ?: return null, nonce, o.bytes("proof") ?: return null)
                }
                "error" -> Error(o.str("reason", ""))
                "state" -> {
                    val sentAt = o.num("sentAt", Double.NaN).takeIf { !it.isNaN() } ?: return null
                    State(EngineState.fromWire(o.obj("state")) ?: return null, sentAt)
                }
                "unpair" -> Unpair
                "ping" -> Ping
                "" -> null
                else -> Unknown
            }
        }
    }
}

/** The wire form: like the saved one, but with the day as a date. */
fun EngineState.toWire(): JSONObject = toJson()
    .apply { remove("countedDay") }
    .put("day", LocalDate.ofEpochDay(countedDay).toString())

fun EngineState.Companion.fromWire(o: JSONObject?): EngineState? {
    if (o == null || o.num("changedAt", Double.NaN).isNaN()) return null
    val day = try {
        LocalDate.parse(o.str("day", "")).toEpochDay()
    } catch (_: Exception) {
        0L
    }
    return fromJsonObject(JSONObject(o, o.keys().asSequence().toList().toTypedArray()).put("countedDay", day))
}

/** Moves the sender's times onto the receiver's clock. */
fun EngineState.shifted(offset: Double): EngineState =
    copy(endsAt = endsAt?.plus(offset), changedAt = SyncRules.shifted(changedAt, offset))

object SyncRules {
    /** Changes closer than this count as simultaneous, and the Mac wins. */
    const val TIE_WINDOW = 1.0

    /** A change time on the receiver's clock. 0 stays 0: "never changed". */
    fun shifted(changedAt: Double, offset: Double): Double = if (changedAt == 0.0) 0.0 else changedAt + offset

    /**
     * Whether the receiver takes the other device's state. Both times are on the
     * receiver's clock. A state nobody changed (time 0) always loses, and of two
     * such states the phone's wins: it kept its timer, the Mac did not.
     */
    fun shouldAdopt(local: Double, remote: Double, receiverIsMac: Boolean): Boolean =
        if (receiverIsMac) local == 0.0 || remote - local > TIE_WINDOW else remote != 0.0 && remote - local >= -TIE_WINDOW
}

/** What the pairing QR on the Mac says. */
class PairLink(
    val macId: String,
    val publicKey: ByteArray,
    val token: ByteArray,
    val addresses: List<String>,
    val port: Int,
) {
    companion object {
        fun parse(link: String): PairLink? {
            val uri = try {
                URI(link)
            } catch (_: Exception) {
                return null
            }
            if (uri.scheme != "pomodoro" || uri.host != "pair") return null
            val q = (uri.rawQuery ?: return null).split("&").associate {
                it.substringBefore("=") to it.substringAfter("=", "")
            }
            if (q["v"] != SYNC_VERSION.toString()) return null
            val id = q["id"]?.ifEmpty { null } ?: return null
            val key = q["k"]?.let(::fromBase64Url)?.takeIf { it.size == 65 } ?: return null
            val token = q["t"]?.let(::fromBase64Url)?.takeIf { it.size == 16 } ?: return null
            val port = q["p"]?.toIntOrNull()?.takeIf { it in 1..65535 } ?: return null
            val addresses = q["a"].orEmpty().split(",").filter { it.isNotEmpty() }
            return PairLink(id, key, token, addresses, port)
        }
    }
}

fun ByteArray.base64Url(): String = Base64.getUrlEncoder().withoutPadding().encodeToString(this)

fun fromBase64Url(text: String): ByteArray? =
    try {
        Base64.getUrlDecoder().decode(text)
    } catch (_: IllegalArgumentException) {
        null
    }

private fun JSONObject.bytes(key: String): ByteArray? = (opt(key) as? String)?.let(::fromBase64Url)
