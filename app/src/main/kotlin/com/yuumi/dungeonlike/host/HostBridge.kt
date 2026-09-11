package com.yuumi.dungeonlike.host

import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot

/**
 * The complete host-to-engine bridge surface.
 *
 * # Why this class is the whole surface
 *
 * `THREAT_MODEL.md` boundary 4 treats everything crossing this bridge as
 * untrusted in both directions, because GDScript is analysed by neither CodeQL
 * nor super-linter (ADR 0002) and therefore carries no automated security
 * coverage. Two rules follow, and they are the reason this class exists at all
 * rather than the activity exposing methods ad hoc:
 *
 * 1. **Everything reachable from the engine is declared here.** A method the
 *    engine can call is annotated [UsedByGodot]; a signal it can receive is
 *    listed in [getPluginSignals]. Reviewing the bridge means reading one file.
 * 2. **Nothing capability-bearing is exposed.** No file system, no storage, no
 *    credentials, no entitlement state, no arbitrary `Intent` dispatch. The
 *    surface below answers one question — which input devices are attached —
 *    and returns a value from a closed set.
 *
 * Adding a member here is a security-relevant change and requires the threat
 * model to be revisited, per its own review triggers.
 *
 * @param godot the engine instance this plugin is registered with.
 * @param inputMode supplies the current interaction model on demand. Injected
 *   rather than read directly so the bridge holds no Android state of its own.
 */
class HostBridge(
    godot: Godot,
    private val inputMode: () -> InputMode,
) : GodotPlugin(godot) {
    override fun getPluginName(): String = PLUGIN_NAME

    override fun getPluginSignals(): MutableSet<SignalInfo> = mutableSetOf(SignalInfo(SIGNAL_INPUT_MODE_CHANGED, String::class.java))

    /**
     * Returns the current interaction model as one of [InputMode.engineValue].
     *
     * Callable from GDScript through the engine singleton named [PLUGIN_NAME].
     * The return type is a closed set of strings, so the engine cannot be handed
     * a value it has no branch for.
     */
    @UsedByGodot
    fun getInputMode(): String = inputMode().engineValue

    /**
     * Tells the engine that the attached input devices changed.
     *
     * Called by the host when a peripheral is connected or removed mid-session,
     * which is an explicit release gate in `docs/release/READINESS.md`: a player
     * who plugs in a keyboard mid-run must not have to restart to use it.
     */
    fun notifyInputModeChanged(mode: InputMode) {
        emitSignal(SIGNAL_INPUT_MODE_CHANGED, mode.engineValue)
    }

    companion object {
        /**
         * Name of the engine singleton the GDScript side looks up. Part of the
         * cross-language contract; changing it breaks the game core silently,
         * because a missing singleton is a null lookup rather than an error.
         */
        const val PLUGIN_NAME: String = "DungeonLikeHost"

        /** Emitted with the new [InputMode.engineValue] when peripherals change. */
        const val SIGNAL_INPUT_MODE_CHANGED: String = "input_mode_changed"
    }
}
