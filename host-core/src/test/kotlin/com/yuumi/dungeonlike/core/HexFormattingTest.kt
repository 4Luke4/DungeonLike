package com.yuumi.dungeonlike.core

import org.junit.jupiter.api.Assertions.assertArrayEquals
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test

class HexFormattingTest {

    @Test
    @DisplayName("bytes round-trip through their hexadecimal form")
    fun roundTrips() {
        val bytes = ByteArray(256) { index -> index.toByte() }

        assertArrayEquals(bytes, HexFormatting.fromHex(HexFormatting.toHex(bytes)))
    }

    @Test
    @DisplayName("high bytes keep their leading zero and stay lower-case")
    fun formatsBytesAsTwoLowerCaseDigits() {
        assertEquals("000f80ff", HexFormatting.toHex(byteArrayOf(0, 15, -128, -1)))
    }

    @Test
    @DisplayName("a pasted seed is accepted in either case")
    fun parsesUpperCase() {
        assertArrayEquals(HexFormatting.fromHex("ABCDEF"), HexFormatting.fromHex("abcdef"))
    }

    @Test
    @DisplayName("malformed text is rejected rather than silently coerced")
    fun rejectsMalformedText() {
        // A truncated or mistyped seed must be reported: quietly accepting it
        // would start a different run from the one the player meant to replay.
        assertThrows(IllegalArgumentException::class.java) { HexFormatting.fromHex("abc") }
        assertThrows(IllegalArgumentException::class.java) { HexFormatting.fromHex("zz") }
    }
}
