package com.yuumi.dungeonlike.core

/**
 * Lower-case hexadecimal conversion.
 *
 * A run seed is shown to the player and pasted into bug reports, so it needs a
 * stable, case-insensitive textual form that round-trips exactly.
 */
object HexFormatting {
    private const val DIGITS = "0123456789abcdef"

    fun toHex(bytes: ByteArray): String {
        val builder = StringBuilder(bytes.size * 2)
        for (byte in bytes) {
            val value = byte.toInt() and 0xFF
            builder.append(DIGITS[value ushr 4])
            builder.append(DIGITS[value and 0x0F])
        }
        return builder.toString()
    }

    /**
     * Parses a hexadecimal string, accepting either case.
     *
     * @throws IllegalArgumentException if the text has an odd length or holds a
     *   character that is not a hexadecimal digit. Seeds are typed and pasted by
     *   hand, so a malformed one must be reported rather than silently coerced
     *   into a different run.
     */
    fun fromHex(text: String): ByteArray {
        require(text.length % 2 == 0) { "hexadecimal text must have an even length, was ${text.length}" }
        val bytes = ByteArray(text.length / 2)
        for (index in bytes.indices) {
            val high = digit(text[index * 2])
            val low = digit(text[index * 2 + 1])
            bytes[index] = ((high shl 4) or low).toByte()
        }
        return bytes
    }

    private fun digit(character: Char): Int {
        val value = DIGITS.indexOf(character.lowercaseChar())
        require(value >= 0) { "'$character' is not a hexadecimal digit" }
        return value
    }
}
