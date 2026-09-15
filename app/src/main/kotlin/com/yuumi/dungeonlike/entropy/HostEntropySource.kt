package com.yuumi.dungeonlike.entropy

import java.security.SecureRandom

/**
 * Platform entropy for run seeds.
 *
 * The game combines this with the engine's own cryptographic generator before
 * deriving a run seed, so that a weakness in either source alone cannot make a
 * run predictable. See `docs/rng/RNG_DESIGN.md`.
 *
 * [SecureRandom]'s no-argument constructor is used deliberately.
 * `SecureRandom.getInstanceStrong()` can block for an unbounded time while the
 * kernel entropy pool fills, which on a cold device boot would stall the first
 * run of the game; the default instance on Android is seeded from the same
 * kernel source and is the provider Android documents for cryptographic use.
 */
class HostEntropySource(
    private val random: SecureRandom = SecureRandom(),
) {
    /**
     * Returns [byteCount] fresh bytes.
     *
     * @throws IllegalArgumentException if [byteCount] is outside [1, MAX_BYTES].
     *   The bound exists because this is reachable from game code across the
     *   engine bridge: an unbounded length would let a scripting mistake
     *   allocate arbitrarily.
     */
    fun nextBytes(byteCount: Int): ByteArray {
        require(byteCount in 1..MAX_BYTES) {
            "byteCount must be between 1 and $MAX_BYTES, was $byteCount"
        }
        return ByteArray(byteCount).also(random::nextBytes)
    }

    companion object {
        /** Generous upper bound: a run seed is 32 bytes. */
        const val MAX_BYTES: Int = 1024
    }
}
