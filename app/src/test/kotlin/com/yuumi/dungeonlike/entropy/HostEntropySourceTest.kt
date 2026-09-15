package com.yuumi.dungeonlike.entropy

import java.security.SecureRandom
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test

class HostEntropySourceTest {

    private val source = HostEntropySource(SecureRandom())

    @Test
    @DisplayName("returns exactly the requested number of bytes")
    fun returnsRequestedLength() {
        assertEquals(32, source.nextBytes(32).size)
        assertEquals(1, source.nextBytes(1).size)
        assertEquals(HostEntropySource.MAX_BYTES, source.nextBytes(HostEntropySource.MAX_BYTES).size)
    }

    @Test
    @DisplayName("successive draws differ")
    fun drawsAreNotRepeated() {
        // A generator that returned a constant would still satisfy the length
        // assertions above, so the behaviour that actually matters is checked
        // separately. Two independent 32-byte draws colliding is not a credible
        // outcome for a working generator.
        val first = source.nextBytes(32)
        val second = source.nextBytes(32)

        assertFalse(first.contentEquals(second))
    }

    @Test
    @DisplayName("out-of-range requests are refused")
    fun rejectsOutOfRangeRequests() {
        // The bound exists because this is reachable from game code across the
        // engine bridge; an unbounded length would let a scripting mistake
        // allocate arbitrarily.
        assertThrows(IllegalArgumentException::class.java) { source.nextBytes(0) }
        assertThrows(IllegalArgumentException::class.java) { source.nextBytes(-1) }
        assertThrows(IllegalArgumentException::class.java) {
            source.nextBytes(HostEntropySource.MAX_BYTES + 1)
        }
    }
}
