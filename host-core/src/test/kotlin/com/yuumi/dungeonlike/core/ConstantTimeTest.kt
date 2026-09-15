package com.yuumi.dungeonlike.core

import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test

class ConstantTimeTest {

    @Test
    @DisplayName("identical byte arrays compare equal")
    fun acceptsIdenticalArrays() {
        assertTrue(ConstantTime.equals(ByteArray(32) { it.toByte() }, ByteArray(32) { it.toByte() }))
    }

    @Test
    @DisplayName("a difference in the last byte is still detected")
    fun rejectsDifferenceAtTheEnd() {
        // The interesting case: an early-returning comparison gets this one
        // right too, but takes longer over it than over a difference in the
        // first byte. The assertion here is correctness; the timing property is
        // a matter of the implementation examining every byte regardless.
        val expected = ByteArray(32) { 0x5a }
        val forged = expected.copyOf().also { it[it.lastIndex] = 0x5b }
        assertFalse(ConstantTime.equals(expected, forged))
    }

    @Test
    @DisplayName("a difference in the first byte is detected")
    fun rejectsDifferenceAtTheStart() {
        val expected = ByteArray(32) { 0x5a }
        val forged = expected.copyOf().also { it[0] = 0x00 }
        assertFalse(ConstantTime.equals(expected, forged))
    }

    @Test
    @DisplayName("arrays of different lengths are never equal")
    fun rejectsDifferentLengths() {
        assertFalse(ConstantTime.equals(ByteArray(32), ByteArray(31)))
    }

    @Test
    @DisplayName("two empty arrays compare equal")
    fun acceptsEmptyArrays() {
        // Degenerate, but reachable: an absent tag arrives as an empty array,
        // and the caller must decide what that means rather than being handed a
        // spurious mismatch.
        assertTrue(ConstantTime.equals(ByteArray(0), ByteArray(0)))
    }
}
