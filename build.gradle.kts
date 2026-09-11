// Root build script.
//
// Deliberately declarative-only: plugins are resolved here but applied in the
// modules that use them, so the root project stays free of Android or Kotlin
// configuration that a single module owns.

plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.android) apply false
}
