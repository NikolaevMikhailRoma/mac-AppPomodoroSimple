package com.nikolaev.pomodoro.core

import java.math.BigInteger
import java.nio.ByteBuffer
import java.security.AlgorithmParameters
import java.security.KeyFactory
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.PrivateKey
import java.security.interfaces.ECPublicKey
import java.security.spec.ECGenParameterSpec
import java.security.spec.ECParameterSpec
import java.security.spec.ECPoint
import java.security.spec.ECPrivateKeySpec
import java.security.spec.ECPublicKeySpec
import javax.crypto.Cipher
import javax.crypto.KeyAgreement
import javax.crypto.Mac
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

// Keys and frames of docs/SYNC.md, the counterpart of SyncCrypto.swift.
// Only the platform's java.security and javax.crypto; nothing hand-rolled
// beyond HKDF, which is two HMAC calls (RFC 5869).

object SyncCrypto {
    private val p256: ECParameterSpec = AlgorithmParameters.getInstance("EC").run {
        init(ECGenParameterSpec("secp256r1"))
        getParameterSpec(ECParameterSpec::class.java)
    }

    /** A key pair made for one pairing only. */
    fun newKeyPair(): KeyPair =
        KeyPairGenerator.getInstance("EC").apply { initialize(ECGenParameterSpec("secp256r1")) }.generateKeyPair()

    /** For the test vectors. */
    fun privateKey(raw: ByteArray): PrivateKey =
        KeyFactory.getInstance("EC").generatePrivate(ECPrivateKeySpec(BigInteger(1, raw), p256))

    /** Uncompressed X9.63, the form CryptoKit reads: 04 ‖ X ‖ Y. */
    fun encode(key: ECPublicKey): ByteArray = byteArrayOf(4) + key.w.affineX.to32() + key.w.affineY.to32()

    fun publicKeyFrom(x963: ByteArray): ECPublicKey {
        require(x963.size == 65 && x963[0] == 4.toByte()) { "not an uncompressed P-256 key" }
        val point = ECPoint(BigInteger(1, x963.copyOfRange(1, 33)), BigInteger(1, x963.copyOfRange(33, 65)))
        return KeyFactory.getInstance("EC").generatePublic(ECPublicKeySpec(point, p256)) as ECPublicKey
    }

    /** The long-lived key a pairing ends with. The token salts it, so the QR and the key exchange are both needed. */
    fun deviceKey(privateKey: PrivateKey, peerPublicKey: ByteArray, token: ByteArray): ByteArray {
        val agreement = KeyAgreement.getInstance("ECDH")
        agreement.init(privateKey)
        agreement.doPhase(publicKeyFrom(peerPublicKey), true)
        return hkdf(agreement.generateSecret(), token, "pomodoro-key-v1")
    }

    /** Proves to the Mac that the phone read the QR. */
    fun proof(token: ByteArray, phonePublicKey: ByteArray, macPublicKey: ByteArray): ByteArray =
        hmac(token, "pomodoro-pair-v1".toByteArray() + phonePublicKey + macPublicKey)

    /** c2s, then s2c. */
    fun sessionKeys(deviceKey: ByteArray, nonceClient: ByteArray, nonceServer: ByteArray): kotlin.Pair<ByteArray, ByteArray> =
        hkdf(deviceKey, nonceClient + nonceServer, "pomodoro-c2s-v1") to
            hkdf(deviceKey, nonceClient + nonceServer, "pomodoro-s2c-v1")

    /** HKDF-SHA256 with one output block, which is all 32 bytes need. */
    private fun hkdf(ikm: ByteArray, salt: ByteArray, info: String): ByteArray =
        hmac(hmac(salt, ikm), info.toByteArray() + byteArrayOf(1))

    private fun hmac(key: ByteArray, message: ByteArray): ByteArray =
        Mac.getInstance("HmacSHA256").run {
            init(SecretKeySpec(key, "HmacSHA256"))
            doFinal(message)
        }

    private fun BigInteger.to32(): ByteArray {
        val b = toByteArray()
        return when {
            b.size == 32 -> b
            b.size > 32 -> b.copyOfRange(b.size - 32, b.size) // a leading sign byte
            else -> ByteArray(32 - b.size) + b
        }
    }
}

/** One connection's encryption: a key and a counter for each direction. */
class SessionCipher(private val sendKey: ByteArray, private val receiveKey: ByteArray) {
    private var sent = 0L
    private var received = 0L

    fun seal(plaintext: ByteArray): ByteArray = cipher(Cipher.ENCRYPT_MODE, sendKey, sent++).doFinal(plaintext)

    /** Throws on a forged, reordered or replayed frame; the caller closes the connection. */
    fun open(payload: ByteArray): ByteArray {
        val plaintext = cipher(Cipher.DECRYPT_MODE, receiveKey, received).doFinal(payload)
        received++
        return plaintext
    }

    private fun cipher(mode: Int, key: ByteArray, counter: Long): Cipher =
        Cipher.getInstance("AES/GCM/NoPadding").apply {
            val nonce = ByteBuffer.allocate(12).putInt(0).putLong(counter).array()
            init(mode, SecretKeySpec(key, "AES"), GCMParameterSpec(128, nonce))
        }
}

/** A frame is a 4-byte big-endian length, 1…16384, then the payload. */
object Frames {
    const val MAX_LENGTH = 16384

    fun frame(payload: ByteArray): ByteArray = ByteBuffer.allocate(4).putInt(payload.size).array() + payload

    /** Throws on a length the protocol does not allow. */
    fun checkLength(length: Int) {
        require(length in 1..MAX_LENGTH) { "bad frame length $length" }
    }
}
