package com.yuumi.dungeonlike.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotEquals
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test

class SeedDerivationTest {

    @Test
    @DisplayName("a run seed is 32 bytes and depends on both entropy sources")
    fun derivesFixedLengthSeedFromBothSources() {
        val platform = ByteArray(32) { 0x11 }
        val engine = ByteArray(32) { 0x22 }

        val seed = SeedDerivation.deriveRunSeed(platform, engine)

        assertEquals(SeedDerivation.SEED_LENGTH, seed.size)
        assertNotEquals(
            HexFormatting.toHex(seed),
            HexFormatting.toHex(SeedDerivation.deriveRunSeed(platform, ByteArray(32) { 0x23 })),
        )
        assertNotEquals(
            HexFormatting.toHex(seed),
            HexFormatting.toHex(SeedDerivation.deriveRunSeed(ByteArray(32) { 0x12 }, engine)),
        )
    }

    @Test
    @DisplayName("cross-implementation vectors: the engine side must derive the same seeds")
    fun matchesSharedKnownAnswerVectors() {
        // These are the vectors `game/tests/unit/test_rng_service.gd` asserts
        // against. They are what actually ties the Kotlin and GDScript
        // derivations together: if either implementation is changed, one of the
        // two suites fails instead of runs quietly replaying differently.
        assertEquals(
            "885f2e0818c469fdf70db469c23591acac8cd34a1a6ed318f59a3fce6fed66d9",
            HexFormatting.toHex(
                SeedDerivation.deriveRunSeed(ByteArray(32) { 0x11 }, ByteArray(32) { 0x22 }),
            ),
        )
        assertEquals(
            "e7d45c80c9427057a62ae89cf5dc1d877c8f525e8e04a954f8f08dcaf31d957f",
            HexFormatting.toHex(
                SeedDerivation.deriveRunSeed(ByteArray(0), ByteArray(32) { 0x7f }),
            ),
        )
    }

    @Test
    @DisplayName("the same inputs always derive the same seed")
    fun isDeterministic() {
        val platform = HexFormatting.fromHex("a1b2c3d4")
        val engine = HexFormatting.fromHex("0f1e2d3c")

        assertEquals(
            HexFormatting.toHex(SeedDerivation.deriveRunSeed(platform, engine)),
            HexFormatting.toHex(SeedDerivation.deriveRunSeed(platform, engine)),
        )
    }

    @Test
    @DisplayName("length prefixing keeps a shifted split from colliding")
    fun lengthPrefixPreventsAmbiguity() {
        // Without length prefixes these two calls would hash identical material
        // and produce the same run, letting whichever source was larger decide
        // the outcome on its own.
        val first = SeedDerivation.deriveRunSeed(HexFormatting.fromHex("aabb"), HexFormatting.fromHex("cc"))
        val second = SeedDerivation.deriveRunSeed(HexFormatting.fromHex("aa"), HexFormatting.fromHex("bbcc"))

        assertNotEquals(HexFormatting.toHex(first), HexFormatting.toHex(second))
    }

    @Test
    @DisplayName("a single available source still yields a seed")
    fun toleratesOneMissingSource() {
        // On desktop and in the editor there is no Android host, so the
        // platform half is absent. The run is still seeded, and the game
        // records that it was seeded from one source only.
        val seed = SeedDerivation.deriveRunSeed(ByteArray(0), ByteArray(32) { 0x7f })

        assertEquals(SeedDerivation.SEED_LENGTH, seed.size)
    }

    @Test
    @DisplayName("a run with no entropy at all is refused")
    fun rejectsEmptyEntropy() {
        assertThrows(IllegalArgumentException::class.java) {
            SeedDerivation.deriveRunSeed(ByteArray(0), ByteArray(0))
        }
    }
}
