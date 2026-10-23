package com.nikolaev.pomodoro.sync

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import androidx.core.content.edit
import com.nikolaev.pomodoro.core.base64Url
import com.nikolaev.pomodoro.core.fromBase64Url
import java.security.KeyStore
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * The Mac this phone is paired with. The device key is stored encrypted under
 * an Android Keystore key, which never leaves the phone's secure hardware: a
 * copy of the app's files (a backup, say) cannot be used to read it.
 */
class PairedMac(context: Context) {
    private val prefs = context.getSharedPreferences("sync", Context.MODE_PRIVATE)

    /** Not a secret: the Mac uses it to find this phone's key. */
    val phoneId: String = prefs.getString(KEY_PHONE_ID, null) ?: randomBytes(16).base64Url().also {
        prefs.edit { putString(KEY_PHONE_ID, it) }
    }

    val macId: String? get() = prefs.getString(KEY_MAC_ID, null)

    /** The last address the Mac answered on, for when discovery finds nothing. */
    val lastAddress: Pair<String, Int>? get() {
        val host = prefs.getString(KEY_HOST, null) ?: return null
        return host to prefs.getInt(KEY_PORT, 0)
    }

    /** Null when not paired, or when the Keystore key is gone (a restored backup). */
    fun deviceKey(): ByteArray? {
        val stored = prefs.getString(KEY_DEVICE_KEY, null)?.let(::fromBase64Url) ?: return null
        return try {
            Cipher.getInstance(TRANSFORMATION).run {
                init(Cipher.DECRYPT_MODE, keystoreKey(), GCMParameterSpec(128, stored, 0, IV_SIZE))
                doFinal(stored, IV_SIZE, stored.size - IV_SIZE)
            }
        } catch (_: Exception) {
            null
        }
    }

    fun save(macId: String, deviceKey: ByteArray, host: String, port: Int) {
        val cipher = Cipher.getInstance(TRANSFORMATION).apply { init(Cipher.ENCRYPT_MODE, keystoreKey()) }
        val wrapped = cipher.iv + cipher.doFinal(deviceKey)
        prefs.edit {
            putString(KEY_MAC_ID, macId)
            putString(KEY_DEVICE_KEY, wrapped.base64Url())
            putString(KEY_HOST, host)
            putInt(KEY_PORT, port)
        }
    }

    fun saveAddress(host: String, port: Int) = prefs.edit {
        putString(KEY_HOST, host)
        putInt(KEY_PORT, port)
    }

    fun forget() {
        prefs.edit {
            remove(KEY_MAC_ID)
            remove(KEY_DEVICE_KEY)
            remove(KEY_HOST)
            remove(KEY_PORT)
        }
        KeyStore.getInstance(KEYSTORE).apply { load(null) }.deleteEntry(ALIAS)
    }

    private fun keystoreKey(): SecretKey {
        val store = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        (store.getKey(ALIAS, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE).run {
            init(
                KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setKeySize(256)
                    .build(),
            )
            generateKey()
        }
    }

    companion object {
        fun randomBytes(count: Int): ByteArray = ByteArray(count).also(SecureRandom()::nextBytes)

        private const val KEYSTORE = "AndroidKeyStore"
        private const val ALIAS = "pomodoro-sync"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val IV_SIZE = 12
        private const val KEY_PHONE_ID = "phoneId"
        private const val KEY_MAC_ID = "macId"
        private const val KEY_DEVICE_KEY = "deviceKey"
        private const val KEY_HOST = "host"
        private const val KEY_PORT = "port"
    }
}
