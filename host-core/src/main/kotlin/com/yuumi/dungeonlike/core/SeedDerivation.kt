package com.yuumi.dungeonlike.core

/**
 * Derives the seed a run is generated from.
 *
 * Every run draws entropy from two independent sources — the Android platform's
 * [java.security.SecureRandom] and the engine's own cryptographic generator —
 * and mixes them here. Using both means a weakness in either one alone cannot
 * make a run predictable, and the game records which sources were actually
 * available so a run seeded by only one of them is never mistaken for a fully
 * seeded one.
 *
 * The derivation is deterministic: the same inputs always produce the same
 * seed, and the same seed always produces the same run. That is what makes a
 * run reproducible from a bug report and testable in CI.
 * `game/scripts/autoload/rng_service.gd` performs the identical computation on
 * the engine side; both are checked against the same vectors.
 */
object SeedDerivation {
    /** Length of a run seed, in bytes. */
    const val SEED_LENGTH: Int = 32

    /**
     * Domain separator. Versioned so that a future change to how seeds are
     * derived cannot silently produce different runs from seeds that were
     * recorded under the old scheme.
     */
    private val SALT: ByteArray = "DungeonLike/run-seed/v1".toByteArray(Charsets.UTF_8)

    /** Label bound into the expand step; see [Hkdf.expand]. */
    private val INFO: ByteArray = "run-seed".toByteArray(Charsets.UTF_8)

    /**
     * Combines platform and engine entropy into a [SEED_LENGTH]-byte run seed.
     *
     * The two inputs are length-prefixed before being concatenated. Without the
     * prefix, `(a, b)` and `(a || b, empty)` would hash to the same seed, which
     * would let a caller that controls one source influence the result more
     * than it should.
     *
     * @throws IllegalArgumentException if both sources are empty, which would
     *   mean the run has no entropy at all.
     */
    fun deriveRunSeed(platformEntropy: ByteArray, engineEntropy: ByteArray): ByteArray {
        require(platformEntropy.isNotEmpty() || engineEntropy.isNotEmpty()) {
            "a run seed needs entropy from at least one source"
        }

        val material = lengthPrefixed(platformEntropy) + lengthPrefixed(engineEntropy)
        return Hkdf.derive(SALT, material, INFO, SEED_LENGTH)
    }

    /** Big-endian four-byte length followed by the bytes themselves. */
    private fun lengthPrefixed(bytes: ByteArray): ByteArray {
        val size = bytes.size
        val prefix = byteArrayOf(
            (size ushr 24).toByte(),
            (size ushr 16).toByte(),
            (size ushr 8).toByte(),
            size.toByte(),
        )
        return prefix + bytes
    }
}
