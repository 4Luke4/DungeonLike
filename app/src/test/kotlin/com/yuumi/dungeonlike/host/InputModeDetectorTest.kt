package com.yuumi.dungeonlike.host

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Covers the input-device classification rules.
 *
 * These run on the JVM with no Android framework present, which is possible
 * only because the rules are expressed over [InputDeviceSnapshot] rather than
 * over the platform's `InputDevice`.
 */
class InputModeDetectorTest {
    @Test
    fun `no devices means touch`() {
        assertEquals(InputMode.TOUCH, InputModeDetector.classify(emptyList()))
    }

    @Test
    fun `a mouse alone means mouse`() {
        assertEquals(InputMode.MOUSE, InputModeDetector.classify(listOf(MOUSE)))
    }

    @Test
    fun `a physical keyboard alone means keyboard`() {
        assertEquals(InputMode.KEYBOARD, InputModeDetector.classify(listOf(KEYBOARD)))
    }

    @Test
    fun `a mouse and a keyboard together mean both`() {
        assertEquals(
            InputMode.MOUSE_AND_KEYBOARD,
            InputModeDetector.classify(listOf(MOUSE, KEYBOARD)),
        )
    }

    @Test
    fun `one device providing both capabilities means both`() {
        val combo = InputDeviceSnapshot(isVirtual = false, supportsPointer = true, hasAlphabeticKeys = true)
        assertEquals(InputMode.MOUSE_AND_KEYBOARD, InputModeDetector.classify(listOf(combo)))
    }

    @Test
    fun `the platform's virtual keyboard is not a physical keyboard`() {
        // Regression guard: the on-screen keyboard is enumerated as an input
        // device, so counting it would report a keyboard on every touch-only
        // phone and switch the whole game into the desktop interaction model.
        val virtualKeyboard = KEYBOARD.copy(isVirtual = true)
        assertEquals(InputMode.TOUCH, InputModeDetector.classify(listOf(virtualKeyboard)))
    }

    @Test
    fun `a virtual device is ignored even alongside real hardware`() {
        assertEquals(
            InputMode.MOUSE,
            InputModeDetector.classify(listOf(KEYBOARD.copy(isVirtual = true), MOUSE)),
        )
    }

    @Test
    fun `a touchscreen reporting non-alphabetic keys is not a keyboard`() {
        // Touchscreens, controllers and remotes all advertise a keypad; only an
        // alphabetic keyboard counts.
        val touchscreen = InputDeviceSnapshot(isVirtual = false, supportsPointer = false, hasAlphabeticKeys = false)
        assertEquals(InputMode.TOUCH, InputModeDetector.classify(listOf(touchscreen)))
    }

    private companion object {
        val MOUSE = InputDeviceSnapshot(isVirtual = false, supportsPointer = true, hasAlphabeticKeys = false)
        val KEYBOARD = InputDeviceSnapshot(isVirtual = false, supportsPointer = false, hasAlphabeticKeys = true)
    }
}
