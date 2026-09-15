package com.yuumi.dungeonlike.bridge

import android.content.Context
import com.yuumi.dungeonlike.achievements.AchievementGateway
import com.yuumi.dungeonlike.achievements.NoOpAchievementGateway
import com.yuumi.dungeonlike.display.RefreshRateProvider
import com.yuumi.dungeonlike.entropy.HostEntropySource
import com.yuumi.dungeonlike.input.InputDeviceWatcher
import com.yuumi.dungeonlike.save.KeystoreSaveIntegrity
import com.yuumi.dungeonlike.save.SaveIntegrity
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot

/**
 * The only surface the game core can reach the Android platform through.
 *
 * Everything the engine cannot do for itself — real platform entropy, the
 * panel's refresh rates, which input hardware is attached, achievements —
 * arrives here and nowhere else. Adding a capability means adding a method to
 * this class; opening a second channel would make the boundary unreviewable.
 *
 * Two rules come from the engine rather than from preference:
 *
 *  * a method callable from GDScript must be annotated [UsedByGodot], and the
 *    engine matches the name **exactly** — it performs no `snake_case` to
 *    `camelCase` conversion, so the GDScript call site spells the Kotlin name;
 *  * these methods run on the engine's thread. Each one must be cheap and must
 *    not block, which is why anything the platform pushes asynchronously is
 *    delivered as a signal instead of as a blocking call.
 *
 * On the game side every call goes through `HostBridge`, which degrades
 * gracefully when the plugin is absent so the project still runs in the editor.
 */
class HostPlugin(
    godot: Godot,
    context: Context,
    private val entropySource: HostEntropySource = HostEntropySource(),
    private val refreshRates: RefreshRateProvider = RefreshRateProvider(context),
    private val achievements: AchievementGateway = NoOpAchievementGateway(),
    private val saveIntegrity: SaveIntegrity = KeystoreSaveIntegrity(),
) : GodotPlugin(godot) {

    private val inputDevices = InputDeviceWatcher(context) { capabilities ->
        emitSignal(
            SIGNAL_INPUT_DEVICES_CHANGED,
            capabilities.hasPhysicalKeyboard,
            capabilities.hasPointer,
            capabilities.hasGameController,
        )
    }

    override fun getPluginName(): String = PLUGIN_NAME

    override fun getPluginSignals(): MutableSet<SignalInfo> = mutableSetOf(
        // Emitted whenever a keyboard, pointer or controller is attached or
        // detached, so the interface can switch prompts without polling.
        SignalInfo(
            SIGNAL_INPUT_DEVICES_CHANGED,
            java.lang.Boolean::class.java,
            java.lang.Boolean::class.java,
            java.lang.Boolean::class.java,
        ),
    )

    // --- Lifecycle -----------------------------------------------------------

    override fun onMainStart() {
        // Listening only while the activity is started keeps the callback from
        // holding the activity alive, and matches when the game can actually
        // react to a device change.
        inputDevices.start()

        // Generating the save-integrity key is the one operation behind this
        // bridge that is not trivially cheap, and every bridge method runs on
        // the engine's thread. Doing it here, off that thread, means the first
        // autosave of a run does not stall a frame.
        (saveIntegrity as? KeystoreSaveIntegrity)?.let { keystore ->
            Thread { keystore.warmUp() }.apply { isDaemon = true }.start()
        }
    }

    override fun onMainStop() {
        inputDevices.stop()
    }

    // --- Entropy -------------------------------------------------------------

    /**
     * Returns [byteCount] bytes of platform entropy as a `PackedByteArray`.
     *
     * The game mixes this with the engine's own cryptographic generator before
     * deriving a run seed; neither source is trusted alone. Returns an empty
     * array rather than throwing if the request is out of range, because an
     * exception crossing the engine boundary would take down the game instead
     * of surfacing a scripting mistake.
     */
    @UsedByGodot
    fun hostEntropy(byteCount: Int): ByteArray =
        runCatching { entropySource.nextBytes(byteCount) }.getOrElse { ByteArray(0) }

    // --- Display -------------------------------------------------------------

    /** The refresh rate of the display's current mode, in hertz. */
    @UsedByGodot
    fun displayRefreshRateHz(): Int = refreshRates.currentRefreshRateHz()

    /**
     * Every refresh rate the display supports, ascending, as a
     * `PackedInt32Array`. The settings screen offers these as frame rate caps
     * instead of a hardcoded list that no device may actually support.
     */
    @UsedByGodot
    fun supportedRefreshRatesHz(): IntArray = refreshRates.supportedRefreshRatesHz()

    // --- Input ---------------------------------------------------------------

    /**
     * Whether a physical alphabetic keyboard is attached. Android reports a
     * virtual keyboard device on every phone; that one does not count.
     */
    @UsedByGodot
    fun hasPhysicalKeyboard(): Boolean = inputDevices.currentCapabilities().hasPhysicalKeyboard

    /** Whether a mouse, trackpad or stylus is attached. */
    @UsedByGodot
    fun hasPointerDevice(): Boolean = inputDevices.currentCapabilities().hasPointer

    /** Whether a gamepad or joystick is attached. */
    @UsedByGodot
    fun hasGameController(): Boolean = inputDevices.currentCapabilities().hasGameController

    // --- Achievements --------------------------------------------------------

    /**
     * Whether an achievement backend is present. The game keeps its own record
     * of what the player has done regardless; this only says whether the
     * platform will also be told.
     */
    @UsedByGodot
    fun achievementsAvailable(): Boolean = achievements.isAvailable

    /** Reports an achievement as unlocked. Never blocks, never throws. */
    @UsedByGodot
    fun unlockAchievement(achievementId: String) {
        runCatching { achievements.unlock(achievementId) }
    }

    /** Adds progress to an incremental achievement. Never blocks, never throws. */
    @UsedByGodot
    fun incrementAchievement(achievementId: String, steps: Int) {
        runCatching { achievements.increment(achievementId, steps) }
    }

    // --- Save integrity ------------------------------------------------------

    /**
     * Returns this device's authentication tag for [payload].
     *
     * The tag lets the game detect a save it did not write, so that an altered
     * or corrupted file is reported instead of loaded as though it were valid.
     * It is **not** a lock: the threat model is explicit that the device owner
     * is not an adversary, and a player editing their own save is making a
     * decision about their own game.
     *
     * Returns an empty array rather than throwing when anything goes wrong,
     * including on a device whose Keystore has invalidated the key. The game
     * treats that as "this save carries no signature" and says so, rather than
     * losing the run.
     *
     * The size bound exists because this is reachable from game code across the
     * engine boundary and must therefore treat its argument as untrusted; a
     * scripting mistake must not be able to ask the host to hash an arbitrary
     * amount of memory.
     */
    @UsedByGodot
    fun saveIntegrityTag(payload: ByteArray): ByteArray =
        if (payload.isEmpty() || payload.size > MAX_SAVE_PAYLOAD_BYTES) {
            ByteArray(0)
        } else {
            runCatching { saveIntegrity.tag(payload) }.getOrElse { ByteArray(0) }
        }

    /**
     * Whether [tag] is the tag this device would produce for [payload].
     *
     * False on any failure, which the game reports as a save it cannot vouch
     * for rather than as an error.
     */
    @UsedByGodot
    fun verifySaveIntegrity(payload: ByteArray, tag: ByteArray): Boolean =
        if (payload.isEmpty() || payload.size > MAX_SAVE_PAYLOAD_BYTES) {
            false
        } else {
            runCatching { saveIntegrity.verify(payload, tag) }.getOrElse { false }
        }

    companion object {
        /**
         * Largest save payload the host will authenticate, in bytes. A run's
         * state is a few kilobytes; this is generous enough never to be reached
         * by the game and small enough to bound what a scripting mistake can
         * ask for.
         */
        const val MAX_SAVE_PAYLOAD_BYTES = 4 * 1024 * 1024

        /**
         * The name the game looks the plugin up by, through
         * `Engine.get_singleton()`. Changing it silently disconnects the game
         * from the host, so it is referenced from
         * `game/scripts/autoload/host_bridge.gd` and nowhere else.
         */
        const val PLUGIN_NAME = "DungeonLikeHost"

        const val SIGNAL_INPUT_DEVICES_CHANGED = "input_devices_changed"
    }
}
