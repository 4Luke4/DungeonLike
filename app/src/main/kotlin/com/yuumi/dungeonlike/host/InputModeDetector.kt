package com.yuumi.dungeonlike.host

import android.hardware.input.InputManager
import android.view.InputDevice

/**
 * Determines which interaction model the player is using.
 *
 * The pure classification rules live in [classify] and are unit tested. The
 * Android-specific part is confined to [snapshot] and [detect], which do nothing
 * but translate platform types into [InputDeviceSnapshot].
 */
object InputModeDetector {
    /**
     * Classifies the attached devices.
     *
     * Virtual devices are ignored outright. The platform exposes its on-screen
     * keyboard as an input device, so counting it would report a physical
     * keyboard on every touch-only phone.
     *
     * A device is only treated as a keyboard when it reports alphabetic keys:
     * touchscreens, game controllers and remotes all advertise a non-alphabetic
     * keypad, and treating those as keyboards would switch a player holding a
     * plain phone into the desktop interaction model.
     */
    fun classify(devices: Iterable<InputDeviceSnapshot>): InputMode {
        val attached = devices.filterNot(InputDeviceSnapshot::isVirtual)
        return InputMode.of(
            hasPointer = attached.any(InputDeviceSnapshot::supportsPointer),
            hasPhysicalKeyboard = attached.any(InputDeviceSnapshot::hasAlphabeticKeys),
        )
    }

    /** Reads the currently attached devices and classifies them. */
    fun detect(inputManager: InputManager): InputMode =
        classify(
            // `inputDeviceIds` is an IntArray, which the standard library does
            // not give a `mapNotNull`; converting to a list first keeps the null
            // filtering rather than silently dropping the check.
            inputManager.inputDeviceIds.toList().mapNotNull { deviceId ->
                inputManager.getInputDevice(deviceId)?.let(::snapshot)
            },
        )

    /** Translates a platform device into the framework-free form [classify] consumes. */
    fun snapshot(device: InputDevice): InputDeviceSnapshot =
        InputDeviceSnapshot(
            isVirtual = device.isVirtual,
            // SOURCE_MOUSE covers an ordinary mouse and a touchpad in pointer
            // mode; SOURCE_MOUSE_RELATIVE covers captured-pointer devices, which
            // report relative motion and would otherwise be missed.
            supportsPointer =
                device.supportsSource(InputDevice.SOURCE_MOUSE) ||
                    device.supportsSource(InputDevice.SOURCE_MOUSE_RELATIVE),
            hasAlphabeticKeys =
                device.keyboardType == InputDevice.KEYBOARD_TYPE_ALPHABETIC &&
                    device.supportsSource(InputDevice.SOURCE_KEYBOARD),
        )

    private fun InputDevice.supportsSource(source: Int): Boolean = (sources and source) == source
}
