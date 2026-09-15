package com.yuumi.dungeonlike.achievements

/**
 * Where the game reports progress that the platform may publish as an
 * achievement.
 *
 * The game core is written against this interface rather than against a
 * platform SDK for two reasons. The game is playable entirely offline, so every
 * call must be safe to make when no achievement backend exists; and the backend
 * itself is not wired yet, because unlocking a real achievement requires a Play
 * Console games project and the identifier resources that come with it. See
 * `docs/release/READINESS.md`.
 *
 * Implementations must never block the caller and must never throw: an
 * achievement is a side effect of play, and failing to record one may not
 * interrupt it.
 */
interface AchievementGateway {
    /** Whether a backend is present and usable right now. */
    val isAvailable: Boolean

    /** Marks the achievement identified by [achievementId] as unlocked. */
    fun unlock(achievementId: String)

    /** Adds [steps] to the progress of an incremental achievement. */
    fun increment(achievementId: String, steps: Int)
}

/**
 * The implementation used until Play Games Services is wired.
 *
 * It exists so that the game core can call the gateway unconditionally instead
 * of guarding every call site, and so that the offline build has no dependency
 * on Google Play services at all.
 */
class NoOpAchievementGateway : AchievementGateway {
    override val isAvailable: Boolean = false

    override fun unlock(achievementId: String) = Unit

    override fun increment(achievementId: String, steps: Int) = Unit
}
