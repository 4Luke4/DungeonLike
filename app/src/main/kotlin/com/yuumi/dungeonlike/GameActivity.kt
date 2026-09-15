package com.yuumi.dungeonlike

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
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

        // On a configuration-driven recreation the fragment manager restores the
        // existing fragment; creating a second one would create a second engine
        // instance in the same process.
        val existing = supportFragmentManager.findFragmentById(R.id.godot_fragment_container)
        godotFragment = if (existing is GodotFragment) {
            existing
        } else {
            GodotFragment().also { fragment ->
                supportFragmentManager.beginTransaction()
                    .replace(R.id.godot_fragment_container, fragment)
                    .commitNowAllowingStateLoss()
            }
        }
    }

    /**
     * Command line handed to the engine at startup.
     *
     * The game is shipped as an exported pack rather than as a loose project
     * inside `assets/`, so the engine has to be told which pack to run. The
     * path is resolved relative to the application's asset directory.
     */
    override fun getCommandLine(): MutableList<String> {
        val arguments = ArrayList(super.getCommandLine())
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
        /**
         * Asset-relative path of the exported game pack. CI writes the pack to
         * `app/src/main/assets/game.pck`; the `res://` prefix is how the engine
         * addresses its own asset directory.
         */
        const val GAME_PACK_PATH = "res://game.pck"
    }
}
