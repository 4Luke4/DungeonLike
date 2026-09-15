package com.yuumi.dungeonlike.core

/**
 * Comparisons whose duration does not depend on where two values first differ.
 *
 * This lives in `:host-core` rather than beside its caller because it is the
 * one testable part of save authentication: the Android Keystore has no JVM
 * implementation, so `KeystoreSaveIntegrity` can only be exercised on a device,
 * while the comparison it depends on can be checked by CI on every pull request.
 */
object ConstantTime {

    /**
     * Whether [first] and [second] hold the same bytes.
     *
     * Every byte is examined even after a difference is found. A comparison that
     * returned early would take measurably longer the more of a forged tag was
     * correct, which hands an attacker a way to discover the right tag one byte
     * at a time instead of having to guess all of it at once.
     *
     * Length is compared first and leaks, which is harmless: the tag length is
     * a fixed property of the algorithm and is not a secret.
     */
    fun equals(first: ByteArray, second: ByteArray): Boolean {
        if (first.size != second.size) {
            return false
        }
        var difference = 0
        for (index in first.indices) {
            difference = difference or (first[index].toInt() xor second[index].toInt())
        }
        return difference == 0
    }
}
