package com.yuumi.dungeonlike

import androidx.test.ext.junit.rules.ActivityScenarioRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Smoke test for the host activity.
 *
 * This suite is **not** run by continuous integration: the application is built
 * for `arm64-v8a` only and the hosted runners provide no matching device or
 * emulator. It is written and kept compiling so that it can be run on a real
 * device or an ARM runner before a release; the gap is recorded in
 * `docs/release/READINESS.md`.
 *
 * It uses JUnit 4 because that is what the Android instrumentation runner
 * drives; the JVM unit tests use JUnit 5.
 */
@RunWith(AndroidJUnit4::class)
class GameActivityLaunchTest {

    @get:Rule
    val activityRule = ActivityScenarioRule(GameActivity::class.java)

    @Test
    fun hostsTheEngineFragment() {
        activityRule.scenario.onActivity { activity ->
            val fragment = activity.supportFragmentManager
                .findFragmentById(R.id.godot_fragment_container)

            // The engine must be hosted by the fragment the activity committed;
            // a null fragment here means the engine never started.
            assertNotNull(fragment)
        }
    }

    @Test
    fun usesTheApplicationIdTheStoreListingExpects() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext

        assertEquals("com.yuumi.dungeonlike", context.packageName)
    }
}
