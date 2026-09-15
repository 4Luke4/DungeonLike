package com.yuumi.dungeonlike.core

import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

/**
 * HKDF with SHA-256, as specified in RFC 5869.
 *
 * The game needs to turn raw entropy from two independent sources into a fixed
 * size run seed. Hashing the concatenation directly would work for length, but
 * HKDF is the construction that is actually specified for this job: its extract
 * step concentrates the entropy of inputs that may be biased or partially
 * predictable, and its expand step produces independent output for different
 * `info` labels. That second property is what lets a single run seed feed
 * several independent random streams.
 *
 * This implementation is deliberately plain and is verified against the RFC's
 * own SHA-256 test vectors, because `game/scripts/autoload/rng_service.gd`
 * reimplements the same construction on the engine side and the two must agree
 * byte for byte.
 */
object Hkdf {
    private const val ALGORITHM = "HmacSHA256"

    /** Output length of SHA-256, in bytes. */
    const val HASH_LENGTH: Int = 32

    /**
     * RFC 5869 extract step: turns input keying material into a pseudorandom
     * key of [HASH_LENGTH] bytes.
     *
     * An empty [salt] is valid and, per the RFC, is treated as [HASH_LENGTH]
     * zero bytes.
     */
    fun extract(salt: ByteArray, inputKeyingMaterial: ByteArray): ByteArray {
        val effectiveSalt = if (salt.isEmpty()) ByteArray(HASH_LENGTH) else salt
        return hmac(effectiveSalt, inputKeyingMaterial)
    }

    /**
     * RFC 5869 expand step: stretches a pseudorandom key into [length] bytes
     * bound to [info].
     *
     * Different [info] values produce unrelated output from the same key, which
     * is how one run seed yields independent per-system streams.
     *
     * @throws IllegalArgumentException if [length] exceeds the RFC's limit of
     *   255 hash blocks, which the construction cannot produce.
     */
    fun expand(pseudoRandomKey: ByteArray, info: ByteArray, length: Int): ByteArray {
        require(length in 1..(255 * HASH_LENGTH)) {
            "length must be between 1 and ${255 * HASH_LENGTH}, was $length"
        }

        val output = ByteArray(length)
        var block = ByteArray(0)
        var produced = 0
        var counter = 1

        while (produced < length) {
            // T(n) = HMAC(PRK, T(n-1) || info || n), with T(0) empty.
            val input = block + info + byteArrayOf(counter.toByte())
            block = hmac(pseudoRandomKey, input)
            val take = minOf(block.size, length - produced)
            block.copyInto(output, produced, 0, take)
            produced += take
            counter++
        }

        return output
    }

    /** Extract followed by expand, the full RFC 5869 derivation. */
    fun derive(salt: ByteArray, inputKeyingMaterial: ByteArray, info: ByteArray, length: Int): ByteArray =
        expand(extract(salt, inputKeyingMaterial), info, length)

    private fun hmac(key: ByteArray, message: ByteArray): ByteArray {
        val mac = Mac.getInstance(ALGORITHM)
        mac.init(SecretKeySpec(key, ALGORITHM))
        return mac.doFinal(message)
    }
}
