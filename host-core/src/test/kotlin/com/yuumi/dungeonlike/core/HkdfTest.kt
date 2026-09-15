package com.yuumi.dungeonlike.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotEquals
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test

/**
 * The published test vectors from RFC 5869 appendix A.
 *
 * These matter more than they look: the same construction is reimplemented in
 * GDScript for the engine side, and a known-answer test is the only thing that
 * proves two independent implementations agree. If either side drifts, a run
 * would replay differently from its seed and every reproduction from a bug
 * report would be worthless.
 */
class HkdfTest {

    @Test
    @DisplayName("RFC 5869 A.1: basic case with SHA-256")
    fun rfc5869TestCase1() {
        val ikm = HexFormatting.fromHex("0b".repeat(22))
        val salt = HexFormatting.fromHex("000102030405060708090a0b0c")
        val info = HexFormatting.fromHex("f0f1f2f3f4f5f6f7f8f9")

        val prk = Hkdf.extract(salt, ikm)
        assertEquals(
            "077709362c2e32df0ddc3f0dc47bba6390b6c73bb50f9c3122ec844ad7c2b3e5",
            HexFormatting.toHex(prk),
        )

        val okm = Hkdf.expand(prk, info, 42)
        assertEquals(
            "3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf" +
                "34007208d5b887185865",
            HexFormatting.toHex(okm),
        )
    }

    @Test
    @DisplayName("RFC 5869 A.3: zero-length salt and info")
    fun rfc5869TestCase3() {
        val ikm = HexFormatting.fromHex("0b".repeat(22))

        val prk = Hkdf.extract(ByteArray(0), ikm)
        assertEquals(
            "19ef24a32c717b167f33a91d6f648bdf96596776afdb6377ac434c1c293ccb04",
            HexFormatting.toHex(prk),
        )

        val okm = Hkdf.expand(prk, ByteArray(0), 42)
        assertEquals(
            "8da4e775a563c18f715f802a063c5a31b8a11f5c5ee1879ec3454e5f3c738d2d" +
                "9d201395faa4b61a96c8",
            HexFormatting.toHex(okm),
        )
    }

    @Test
    @DisplayName("different info labels produce unrelated output from one key")
    fun differentInfoProducesDifferentOutput() {
        val prk = Hkdf.extract("salt".toByteArray(), "material".toByteArray())

        val map = Hkdf.expand(prk, "map".toByteArray(), 32)
        val loot = Hkdf.expand(prk, "loot".toByteArray(), 32)

        // This is the property the per-system streams rely on: adding a system
        // must not shift any other system's sequence.
        assertNotEquals(HexFormatting.toHex(map), HexFormatting.toHex(loot))
    }

    @Test
    @DisplayName("output shorter than a hash block is a prefix of a longer one")
    fun shortOutputIsPrefixOfLongOutput() {
        val prk = Hkdf.extract("salt".toByteArray(), "material".toByteArray())

        val short = HexFormatting.toHex(Hkdf.expand(prk, ByteArray(0), 16))
        val long = HexFormatting.toHex(Hkdf.expand(prk, ByteArray(0), 64))

        assertEquals(short, long.take(short.length))
    }

    @Test
    @DisplayName("expansion beyond 255 hash blocks is rejected")
    fun rejectsOverlongExpansion() {
        val prk = Hkdf.extract(ByteArray(0), "material".toByteArray())

        assertThrows(IllegalArgumentException::class.java) {
            Hkdf.expand(prk, ByteArray(0), 255 * Hkdf.HASH_LENGTH + 1)
        }
    }
}
