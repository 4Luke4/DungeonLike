package com.yuumi.dungeonlike.host

/**
 * Builds the command line handed to the embedded engine.
 *
 * Kept separate from the activity, and free of Android types, so the argument
 * contract is unit tested rather than discovered on a device.
 */
object EngineCommandLine {
    /**
     * Documented engine argument that points the engine at a pack file instead
     * of loose project files in `assets/`. Parsed by the engine's `Godot.kt`.
     */
    const val MAIN_PACK_ARGUMENT: String = "--main-pack"

    /** Engine-side scheme for a path inside the application's `assets/` directory. */
    private const val RESOURCE_SCHEME = "res://"

    /**
     * Returns the arguments that load the game from [packAssetPath].
     *
     * @param packAssetPath engine resource path of the pack, for example
     *   `res://game.pck`, resolved relative to the application's assets.
     * @throws IllegalArgumentException if the path is not an engine resource
     *   path. Failing here turns a typo into a build- or test-time error rather
     *   than an engine that starts and then renders nothing.
     */
    fun forGamePack(packAssetPath: String): List<String> {
        require(packAssetPath.startsWith(RESOURCE_SCHEME)) {
            "Game pack path must be an engine resource path starting with '$RESOURCE_SCHEME', found '$packAssetPath'"
        }
        require(packAssetPath.length > RESOURCE_SCHEME.length) {
            "Game pack path must name a file, found only '$RESOURCE_SCHEME'"
        }
        return listOf(MAIN_PACK_ARGUMENT, packAssetPath)
    }
}
