package com.yuumi.dungeonlike.input

import android.content.Context
import android.hardware.input.InputManager
import android.view.InputDevice

/**
 * Tracks which kinds of input hardware are attached.
 *
 * Android tablets and desktop-mode devices routinely gain and lose a keyboard
 * or a mouse while the game is running, and the interface has to follow: key
 * hints, focus behaviour and hit-target sizes differ between touch and pointer
 * input. Polling for this in the game loop would be wasteful, so the host
 * observes the platform callback and pushes a change across the bridge.
 *
 * The watcher is registered while the hosting activity is started and
 * unregistered when it stops; leaving the listener attached would keep a
 * reference to the activity alive for the lifetime of the process.
 */
class InputDeviceWatcher(
    context: Context,
    private val onDevicesChanged: (Capabilities) -> Unit,
) {
    /** What the currently attached hardware can do. */
    data class Capabilities(
        val hasPhysicalKeyboard: Boolean,
        val hasPointer: Boolean,
        val hasGameController: Boolean,
    )

    private val inputManager = context.getSystemService(InputManager::class.java)

    private val listener = object : InputManager.InputDeviceListener {
        override fun onInputDeviceAdded(deviceId: Int) = notifyChanged()
        override fun onInputDeviceRemoved(deviceId: Int) = notifyChanged()

        // Fired when a device's configuration changes, for example when a
        // keyboard layout is switched. The capability set can change even
        // though no device was added or removed.
        override fun onInputDeviceChanged(deviceId: Int) = notifyChanged()
    }

    fun start() {
        inputManager?.registerInputDeviceListener(listener, null)
        notifyChanged()
    }

    fun stop() {
        inputManager?.unregisterInputDeviceListener(listener)
    }

    /**
     * Inspects every attached device and reports the combined capabilities.
     *
     * Virtual devices are ignored: Android exposes a virtual keyboard device on
     * every phone, and treating it as a physical keyboard would put the game
     * permanently into keyboard mode.
     */
    fun currentCapabilities(): Capabilities {
        var keyboard = false
        var pointer = false
        var controller = false

        for (deviceId in InputDevice.getDeviceIds()) {
            val device = InputDevice.getDevice(deviceId) ?: continue
            if (device.isVirtual) {
                continue
            }
            val sources = device.sources

            if (device.keyboardType == InputDevice.KEYBOARD_TYPE_ALPHABETIC) {
                keyboard = true
            }
            if (sources.hasSource(InputDevice.SOURCE_MOUSE) ||
                sources.hasSource(InputDevice.SOURCE_TOUCHPAD) ||
                sources.hasSource(InputDevice.SOURCE_STYLUS)
            ) {
                pointer = true
            }
            if (sources.hasSource(InputDevice.SOURCE_GAMEPAD) ||
                sources.hasSource(InputDevice.SOURCE_JOYSTICK)
            ) {
                controller = true
            }
        }

        return Capabilities(
            hasPhysicalKeyboard = keyboard,
            hasPointer = pointer,
            hasGameController = controller,
        )
    }

    private fun notifyChanged() = onDevicesChanged(currentCapabilities())

    /**
     * Source flags are a bitmask of class and source bits, so equality is the
     * wrong test; a device reports the source only if all of its bits are set.
     */
    private fun Int.hasSource(source: Int): Boolean = (this and source) == source
}
