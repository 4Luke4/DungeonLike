import org.jetbrains.kotlin.gradle.dsl.JvmTarget

// Platform-independent host logic.
//
// Anything the Android host does that can be decided without touching an
// Android API belongs here, because this module's tests run on the JVM in CI
// while instrumentation tests do not run at all (the application is arm64-v8a
// only and hosted runners provide no matching device).
//
// This is an Android library module rather than a plain Kotlin JVM module on
// purpose: AGP 9 provides the Kotlin compiler through built-in Kotlin, so
// applying an AGP plugin here keeps the whole build on a single Kotlin compiler
// and removes the Kotlin-Gradle-plugin-to-AGP compatibility matrix entirely.
// The module still contains no Android API usage and its tests are plain JVM
// unit tests.
plugins {
    alias(libs.plugins.android.library)
}

@Suppress("UNCHECKED_CAST")
val toolchain = rootProject.extra["dungeonlike.toolchain"] as Map<String, String>
val javaVersion = JavaVersion.toVersion(toolchain.getValue("build.java"))

android {
    namespace = "com.yuumi.dungeonlike.core"

    compileSdk {
        version = release(toolchain.getValue("android.compileSdk").toInt()) {
            minorApiLevel = toolchain.getValue("android.compileSdkMinor").toInt()
            // sdkExtension is deliberately NOT set. The platform package for
            // this release, `platforms;android-37.2`, already carries SDK
            // extension level 24 as its base extension, and Google publishes no
            // separately versioned `android-37.2-extNN` package. Declaring the
            // extension here makes AGP resolve the compile SDK as
            // `platforms;android-37.2-ext24` and fail with "Failed to find
            // Platform SDK", because no such package exists to install.
        }
    }
    buildToolsVersion = toolchain.getValue("android.buildTools")

    defaultConfig {
        minSdk { version = release(toolchain.getValue("android.minSdk").toInt()) }
    }

    compileOptions {
        sourceCompatibility = javaVersion
        targetCompatibility = javaVersion
    }

    lint {
        warningsAsErrors = true
        abortOnError = true
    }
}

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.fromTarget(javaVersion.toString())
        allWarningsAsErrors = true
    }
}

tasks.withType<Test>().configureEach {
    useJUnitPlatform()
}

dependencies {
    testImplementation(libs.junit.jupiter)
    testRuntimeOnly(libs.junit.platform.launcher)
}
