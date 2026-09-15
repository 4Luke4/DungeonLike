package com.yuumi.dungeonlike.display

import android.content.Context
import android.view.Display

/**
 * Reports what the panel can actually do, so that the game can pick a frame
 * rate cap instead of assuming one.
 *
 * The game's frame pacing policy caps rendering at a rate the device can
 * sustain rather than leaving it uncapped: on a 120 Hz panel an uncapped
 * renderer burns battery to produce frames the panel never shows. The engine
 * side of that policy lives in `game/scripts/autoload/frame_pacing_service.gd`;
 * this class only supplies the facts it needs.
 */
class RefreshRateProvider(private val context: Context) {
    /**
     * The refresh rate of the mode the display is currently in, in hertz,
     * rounded to the nearest whole rate. Returns [FALLBACK_HZ] when no display
     * is available, which happens if the activity is not attached yet.
     */
    fun currentRefreshRateHz(): Int {
        val display: Display = context.display ?: return FALLBACK_HZ
        return display.refreshRate.toIntSafe()
    }

    /**
     * Every refresh rate the display supports, in hertz, sorted ascending and
     * de-duplicated. A device commonly exposes several modes that differ only
     * in resolution, so the raw mode list contains repeated rates.
     */
    fun supportedRefreshRatesHz(): IntArray {
        val display: Display = context.display ?: return intArrayOf(FALLBACK_HZ)
        return display.supportedModes
            .map { mode -> mode.refreshRate.toIntSafe() }
            .distinct()
            .sorted()
            .toIntArray()
    }

    private fun Float.toIntSafe(): Int =
        if (isFinite() && this > 0f) Math.round(this) else FALLBACK_HZ

    private companion object {
        /**
         * Every Android device refreshes at least this fast, so it is a safe
         * floor when the real value cannot be read.
         */
        const val FALLBACK_HZ = 60
    }
}
