package com.yuumi.dungeonlike.save

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.security.KeyStore
import javax.crypto.KeyGenerator
import javax.crypto.Mac
import javax.crypto.SecretKey

/**
 * Tamper **evidence** for local save data.
 *
 * What this defends against, and what it does not, is deliberate. The device
 * owner can read and edit their own files, and a single-player offline game
 * does not treat its player as an adversary. The purpose here is to detect a
 * save that no longer matches what the game wrote, so that a corrupted or
 * hand-edited file is reported instead of being loaded as if it were valid —
 * which is what turns an edited save into an unreproducible bug report.
 *
 * The key is generated inside the Android Keystore and never leaves it, so the
 * tag cannot be recomputed by copying a file to another device. See
 * `docs/architecture/THREAT_MODEL.md`.
 */
interface SaveIntegrity {
    /** Returns the authentication tag for [payload]. */
    fun tag(payload: ByteArray): ByteArray

    /** Whether [tag] is the tag this device would produce for [payload]. */
    fun verify(payload: ByteArray, tag: ByteArray): Boolean
}

/**
 * [SaveIntegrity] backed by a hardware-bound HMAC key in the Android Keystore.
 */
class KeystoreSaveIntegrity(
    private val keyAlias: String = DEFAULT_KEY_ALIAS,
) : SaveIntegrity {

    override fun tag(payload: ByteArray): ByteArray {
        val mac = Mac.getInstance(MAC_ALGORITHM)
        mac.init(loadOrCreateKey())
        return mac.doFinal(payload)
    }

    override fun verify(payload: ByteArray, tag: ByteArray): Boolean {
        val expected = tag(payload)
        return expected.constantTimeEquals(tag)
    }

    /**
     * Returns the device's save-integrity key, creating it on first use.
     *
     * The key is not user-authentication bound: saves are written while the
     * game runs, including during an autosave the player did not initiate, and
     * requiring authentication would make those writes fail.
     */
    private fun loadOrCreateKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        (keyStore.getKey(keyAlias, null) as? SecretKey)?.let { return it }

        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_HMAC_SHA256, ANDROID_KEYSTORE)
        generator.init(
            KeyGenParameterSpec.Builder(keyAlias, KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY)
                .setDigests(KeyProperties.DIGEST_SHA256)
                .build(),
        )
        return generator.generateKey()
    }

    /**
     * Compares in time independent of where the first difference is. A tag
     * comparison that returns early leaks, through timing, how much of a forged
     * tag was correct.
     */
    private fun ByteArray.constantTimeEquals(other: ByteArray): Boolean {
        if (size != other.size) {
            return false
        }
        var difference = 0
        for (index in indices) {
            difference = difference or (this[index].toInt() xor other[index].toInt())
        }
        return difference == 0
    }

    private companion object {
        const val ANDROID_KEYSTORE = "AndroidKeyStore"
        const val MAC_ALGORITHM = "HmacSHA256"
        const val DEFAULT_KEY_ALIAS = "com.yuumi.dungeonlike.save-integrity"
    }
}
