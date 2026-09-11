package com.yuumi.dungeonlike.host

/**
 * A framework-free description of one attached input device.
 *
 * The Android `InputDevice` type is deliberately not used here. Keeping the
 * classification rules expressible in plain data is what allows them to be unit
 * tested on the JVM without stubbing the framework, which is why
 * `testOptions.unitTests.isReturnDefaultValues` can stay off.
 *
 * @property isVirtual true for the platform's synthetic devices, such as the
 *   on-screen keyboard, which must never be mistaken for attached hardware.
 * @property supportsPointer true when the device reports a mouse-like source.
 * @property hasAlphabeticKeys true when the device reports a full alphabetic
 *   keyboard, as opposed to the non-alphabetic keypad that most touchscreens,
 *   game controllers, and remote controls also report.
 */
data class InputDeviceSnapshot(
    val isVirtual: Boolean,
    val supportsPointer: Boolean,
    val hasAlphabeticKeys: Boolean,
)
