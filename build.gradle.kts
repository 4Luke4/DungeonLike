// Root build script.
//
// Deliberately declarative-only: the plugin is resolved here but applied in the
// module that uses it, so the root project stays free of Android configuration
// that a single module owns.
//
// No Kotlin plugin is declared. AGP 9 provides Kotlin support itself and refuses
// to run alongside `org.jetbrains.kotlin.android`.

plugins {
    alias(libs.plugins.android.application) apply false
}
