package com.yuumi.dungeonlike.achievements

import org.junit.jupiter.api.Assertions.assertDoesNotThrow
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test

class NoOpAchievementGatewayTest {

    private val gateway = NoOpAchievementGateway()

    @Test
    @DisplayName("reports that no backend is available")
    fun reportsUnavailable() {
        assertFalse(gateway.isAvailable)
    }

    @Test
    @DisplayName("accepts calls silently so the game never has to guard them")
    fun acceptsCallsWithoutABackend() {
        // The game reports progress unconditionally. If this implementation
        // threw, every call site would need a guard and an offline player would
        // hit a crash for something that is only a side effect of play.
        assertDoesNotThrow {
            gateway.unlock("first_descent")
            gateway.increment("rooms_cleared", 1)
        }
    }
}
