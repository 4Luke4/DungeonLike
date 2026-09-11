package com.yuumi.dungeonlike

import android.content.Context
import android.hardware.input.InputManager
import android.os.Bundle
import com.yuumi.dungeonlike.host.EngineCommandLine
import com.yuumi.dungeonlike.host.HostBridge
import com.yuumi.dungeonlike.host.InputMode
import com.yuumi.dungeonlike.host.InputModeDetector
import org.godotengine.godot.Godot
import org.godotengine.godot.GodotActivity
import org.godotengine.godot.plugin.GodotPlugin

/**
 * The single Activity that hosts the embedded Godot engine.
 *
 * Intentionally thin (ADR 0002): it starts the engine, tells it where the game
 * pack is, exposes the bridge, and reports input-device changes. It draws no
 * game UI — the engine renders everything the player sees, including menus.
 *
 * Two engine constraints are handled structurally rather than defensively:
 *
 * * **One engine instance per process.** Only this Activity ever hosts one, and
 *   it is the single launcher entry point.
 * * **Resize and orientation configuration events are unsupported and may
 *   crash.** The manifest declares `android:configChanges` for exactly those
 *   events, so Android hands them to this Activity instead of recreating it
 *   underneath the running engine. Adaptive phone and tablet layout is therefore
 *   expressed inside the engine, which resizes safely within one instance.
 */
class DungeonLikeActivity : GodotActivity() {
    private val inputManager: InputManager by lazy {
        getSystemService(Context.INPUT_SERVICE) as InputManager
    }

    /**
     * Held so that a device change can be pushed to the engine while it runs.
     * Null until the engine requests its host plugins.
     */
    private var hostBridge: HostBridge? = null

    /**
     * Reports peripherals appearing or disappearing mid-session.
     *
     * A player who connects a keyboard or mouse during a run must not have to
     * restart the app for it to be usable; that is a release gate, not a nicety.
     */
    private val inputDeviceListener =
        object : InputManager.InputDeviceListener {
            override fun onInputDeviceAdded(deviceId: Int) = publishInputMode()

            override fun onInputDeviceRemoved(deviceId: Int) = publishInputMode()

            // Fires when a device's capabilities change without it being
            // re-enumerated, such as a dock or case keyboard being folded away.
            override fun onInputDeviceChanged(deviceId: Int) = publishInputMode()
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Registered against the main looper by passing a null handler, so
        // callbacks arrive on the thread that owns the engine's lifecycle.
        inputManager.registerInputDeviceListener(inputDeviceListener, null)
    }

    override fun onDestroy() {
        inputManager.unregisterInputDeviceListener(inputDeviceListener)
        hostBridge = null
        super.onDestroy()
    }

    /**
     * Supplies the engine's command line.
     *
     * A new list is returned rather than the superclass's own mutable list: that
     * list backs the Activity's stored parameters, and this method is called
     * more than once during startup, so appending to it in place would duplicate
     * the arguments on every call.
     */
    override fun getCommandLine(): MutableList<String> {
        val arguments = ArrayList(super.getCommandLine())
        arguments.addAll(EngineCommandLine.forGamePack(GAME_PACK_PATH))
        return arguments
    }

    override fun getHostPlugins(engine: Godot): MutableSet<GodotPlugin> {
        val bridge = HostBridge(engine) { currentInputMode() }
        hostBridge = bridge
        return mutableSetOf(bridge)
    }

    private fun currentInputMode(): InputMode = InputModeDetector.detect(inputManager)

    private fun publishInputMode() {
        hostBridge?.notifyInputModeChanged(currentInputMode())
    }

    private companion object {
        /**
         * Location of the exported Godot project inside the application's
         * assets. Produced by the `engine-pack` job in `android.yml` and never
         * committed; `app/build.gradle.kts` fails the build if it is missing.
         */
        const val GAME_PACK_PATH = "res://game.pck"
    }
}
