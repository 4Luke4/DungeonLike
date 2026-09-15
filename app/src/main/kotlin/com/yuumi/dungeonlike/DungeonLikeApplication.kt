package com.yuumi.dungeonlike

import android.app.Application
import android.os.StrictMode

/**
 * Process-level entry point.
 *
 * The application object deliberately owns no game state. The embedded engine
 * is created and destroyed with [GameActivity]; anything cached here would
 * outlive it and, because only one engine instance may exist per process,
 * would be a leak that survives into the next launch.
 */
class DungeonLikeApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        if (BuildConfig.DEBUG) {
            enableStrictMode()
        }
    }

    /**
     * Debug-only diagnostics.
     *
     * Violations are logged rather than fatal: the embedded engine performs its
     * own disk access during startup on the thread it chooses, and killing the
     * process for that would make the debug build unusable while telling us
     * nothing about our own code.
     */
    private fun enableStrictMode() {
        StrictMode.setThreadPolicy(
            StrictMode.ThreadPolicy.Builder()
                .detectAll()
                .penaltyLog()
                .build(),
        )
        StrictMode.setVmPolicy(
            StrictMode.VmPolicy.Builder()
                .detectLeakedClosableObjects()
                .detectLeakedRegistrationObjects()
                .penaltyLog()
                .build(),
        )
    }
}
