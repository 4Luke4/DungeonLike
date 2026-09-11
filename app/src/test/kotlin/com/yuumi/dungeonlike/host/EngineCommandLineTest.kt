package com.yuumi.dungeonlike.host

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

/** Covers the engine argument contract. */
class EngineCommandLineTest {
    @Test
    fun `builds the documented main pack arguments`() {
        assertEquals(
            listOf("--main-pack", "res://game.pck"),
            EngineCommandLine.forGamePack("res://game.pck"),
        )
    }

    @Test
    fun `the argument name matches the engine's parser`() {
        // The engine matches this string literally; a typo would be silently
        // forwarded as an unrecognised argument and the pack would never load.
        assertEquals("--main-pack", EngineCommandLine.MAIN_PACK_ARGUMENT)
    }

    @Test
    fun `rejects a path that is not an engine resource path`() {
        assertThrows(IllegalArgumentException::class.java) {
            EngineCommandLine.forGamePack("game.pck")
        }
    }

    @Test
    fun `rejects an absolute file system path`() {
        assertThrows(IllegalArgumentException::class.java) {
            EngineCommandLine.forGamePack("/data/local/tmp/game.pck")
        }
    }

    @Test
    fun `rejects a scheme with no file name`() {
        assertThrows(IllegalArgumentException::class.java) {
            EngineCommandLine.forGamePack("res://")
        }
    }
}
