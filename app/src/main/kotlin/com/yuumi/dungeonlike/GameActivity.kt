package com.yuumi.dungeonlike

import android.os.Bundle
import android.util.Log
import androidx.appcompat.app.AppCompatActivity
import androidx.annotation.StringRes
import androidx.appcompat.app.AlertDialog
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.yuumi.dungeonlike.bridge.HostPlugin
import org.godotengine.godot.Godot
import org.godotengine.godot.GodotFragment
import org.godotengine.godot.GodotHost
import org.godotengine.godot.plugin.GodotPlugin

/**
 * The single activity of the application: it hosts the embedded Godot engine
 * and owns nothing else.
 *
 * Two constraints from the Godot Android library shape this class and must not
 * be relaxed without re-reading that documentation:
 *
 *  * only one engine instance may exist per process, so this activity is the
 *    only place an engine is created; and
 *  * automatic resize and orientation configuration events can crash an
 *    embedded instance, which is why the manifest declares both a fixed
 *    [android.R.attr.screenOrientation] and a `configChanges` set that keeps
 *    the activity from being recreated. The manifest orientation and the Godot
 *    project's `display/window/handheld/orientation` must stay in agreement.
 */
class GameActivity : AppCompatActivity(), GodotHost {
    private var godotFragment: GodotFragment? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Installed before super.onCreate so the system splash screen stays up
        // until the engine has something to draw; the engine takes a noticeable
        // moment to initialise and an empty window in between reads as a hang.
        installSplashScreen()
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_game)

        // Checked before the engine is created. Without the pack the engine
        // starts and renders nothing, which reaches the player as a black
        // screen with no explanation; failing here can at least say why.
        if (!isGamePackPresent()) {
            showFatalError(R.string.error_game_pack_missing)
            return
        }

        // On a configuration-driven recreation the fragment manager restores the
        // existing fragment; creating a second one would create a second engine
        // instance in the same process.
        val existing = supportFragmentManager.findFragmentById(R.id.godot_fragment_container)
        godotFragment = if (existing is GodotFragment) {
            existing
        } else {
            runCatching {
                GodotFragment().also { fragment ->
                    supportFragmentManager.beginTransaction()
                        .replace(R.id.godot_fragment_container, fragment)
                        .commitNowAllowingStateLoss()
                }
            }.onFailure { failure ->
                Log.e(TAG, "The Godot engine could not be started.", failure)
                showFatalError(R.string.error_engine_start_failed)
            }.getOrNull()
        }
    }

    /**
     * Whether the exported game pack shipped inside this package.
     *
     * A missing pack means a packaging fault rather than anything the player
     * did, so the message offers the only action that can help.
     */
    private fun isGamePackPresent(): Boolean =
        runCatching { assets.open(GAME_PACK_ASSET).close() }.isSuccess

    /**
     * Reports a failure the player cannot recover from and closes the game.
     *
     * A dialog rather than a toast: this is the end of the session, and a
     * message that disappears on its own would leave the player looking at a
     * blank window wondering what happened.
     */
    private fun showFatalError(@StringRes messageId: Int) {
        AlertDialog.Builder(this)
            .setMessage(messageId)
            .setCancelable(false)
            .setPositiveButton(android.R.string.ok) { _, _ -> finish() }
            .setOnDismissListener { finish() }
            .show()
    }

    /**
     * Command line handed to the engine at startup.
     *
     * The game is shipped as an exported pack rather than as a loose project
     * inside `assets/`, so the engine has to be told which pack to run. The
     * path is resolved relative to the application's asset directory.
     */
    override fun getCommandLine(): MutableList<String> {
        // Qualified because this class has two supertypes; an unqualified
        // `super` would not compile, and the interface default must be kept:
        // it carries arguments the engine relies on.
        val arguments = ArrayList(super<GodotHost>.getCommandLine())
        arguments += "--main-pack"
        arguments += GAME_PACK_PATH
        return arguments
    }

    /**
     * Plugins registered with the engine instance this activity hosts.
     *
     * Registering the plugin here, rather than declaring it in the manifest,
     * ties its lifetime to this engine instance and lets it hold a reference to
     * the activity that created it.
     */
    override fun getHostPlugins(engine: Godot): MutableSet<GodotPlugin> =
        mutableSetOf(HostPlugin(engine, this))

    private companion object {
        const val TAG = "GameActivity"

        /** Name of the exported pack inside the package's asset directory. */
        const val GAME_PACK_ASSET = "game.pck"

        /**
         * How the engine addresses that same file: CI writes the pack to
         * `app/src/main/assets/game.pck`, and `res://` is the engine's name for
         * its own asset directory.
         */
        const val GAME_PACK_PATH = "res://" + GAME_PACK_ASSET
    }
}
