package com.yuumi.dungeonlike.host

/**
 * How the player is currently interacting with the device.
 *
 * The host detects this; the engine owns the resulting interaction model
 * (ADR 0002). [engineValue] is the exact string that crosses the bridge, so it
 * is part of the contract with the GDScript side and must not be renamed
 * without changing the engine code that matches on it.
 */
enum class InputMode(
    val engineValue: String,
) {
    /** No pointer or physical keyboard attached: touch only. */
    TOUCH("touch"),

    /** A mouse or equivalent relative pointer is attached, but no keyboard. */
    MOUSE("mouse"),

    /** A physical keyboard is attached, but no pointer. */
    KEYBOARD("keyboard"),

    /** Both a pointer and a physical keyboard are attached. */
    MOUSE_AND_KEYBOARD("mouse_and_keyboard"),
    ;

    companion object {
        /**
         * Resolves the mode from the capabilities currently present.
         *
         * Deliberately total: every combination maps to a mode, so the engine
         * never receives an undefined state.
         */
        fun of(
            hasPointer: Boolean,
            hasPhysicalKeyboard: Boolean,
        ): InputMode =
            when {
                hasPointer && hasPhysicalKeyboard -> MOUSE_AND_KEYBOARD
                hasPointer -> MOUSE
                hasPhysicalKeyboard -> KEYBOARD
                else -> TOUCH
            }
    }
}
