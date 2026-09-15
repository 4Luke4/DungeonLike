import org.jetbrains.kotlin.gradle.dsl.JvmTarget

// The DungeonLike Android application: the host process for the embedded Godot
// engine. Game logic lives in game/ and is loaded from the exported pack; see
// app/CLAUDE.md for what may and may not live in this module.
//
// No Kotlin Gradle plugin is applied. AGP 9 compiles Kotlin itself through
// built-in Kotlin support, and org.jetbrains.kotlin.android is incompatible
// with the AGP 9 DSL.
plugins {
    alias(libs.plugins.android.application)
}

// Every SDK, build-tool and Java value comes from
// config/android/toolchain.properties via the root build script. Nothing in
// this file may restate one.
@Suppress("UNCHECKED_CAST")
val toolchain = rootProject.extra["dungeonlike.toolchain"] as Map<String, String>
val javaVersion = JavaVersion.toVersion(toolchain.getValue("build.java"))

android {
    namespace = "com.yuumi.dungeonlike"

    // Only the COMPILE SDK can express a minor platform release and an SDK
    // extension level; the target and minimum SDK DSLs accept a plain API
    // level. Compiling against 37.2 with extension 24 is what makes the
    // extension-gated APIs of that platform release visible.
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
        applicationId = "com.yuumi.dungeonlike"
        minSdk { version = release(toolchain.getValue("android.minSdk").toInt()) }
        targetSdk { version = release(toolchain.getValue("android.targetSdk").toInt()) }

        // VERSION is the only place the application version is written down.
        versionName = rootProject.extra["dungeonlike.versionName"] as String
        versionCode = rootProject.extra["dungeonlike.versionCode"] as Int

        // 64-bit ARM only. The Godot Android library ships native libraries for
        // several architectures; without this filter every unsupported one
        // would be packaged into the bundle.
        ndk { abiFilters += toolchain.getValue("android.abi") }
    }

    androidResources {
        // Keep resources for the shipped languages only. Without this the
        // bundle carries the AndroidX libraries' translations for every locale
        // they support, none of which this application can display.
        //
        // The list is the same one declared in res/xml/locales_config.xml and
        // in the game's translation table; tools/scripts/check_locales.py fails
        // the build if the declarations disagree.
        localeFilters += setOf("en", "it", "es", "fr", "de")
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
            // No applicationIdSuffix: the application id is what Play Games and
            // Play entitlement checks key on, and a debug build that reports a
            // different id cannot exercise either.
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            // Signing is intentionally absent. Release signing material lives in
            // a protected GitHub environment and is applied by the release
            // workflow; see docs/release/READINESS.md.
        }
    }

    compileOptions {
        sourceCompatibility = javaVersion
        targetCompatibility = javaVersion
    }

    buildFeatures {
        buildConfig = true
    }

    packaging {
        resources {
            // Licence metadata duplicated across dependencies; the in-app
            // licences screen renders notices from THIRD_PARTY_NOTICES.md and
            // from the engine itself instead.
            excludes += setOf(
                "/META-INF/{AL2.0,LGPL2.1}",
                "/META-INF/DEPENDENCIES",
                "/META-INF/*.version",
            )
        }
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
        }
    }

    lint {
        warningsAsErrors = true
        abortOnError = true
        // Written by the CI job so that failures are reviewable as an artifact
        // rather than only as console output.
        sarifReport = true
        htmlReport = true
        xmlReport = false
    }
}

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.fromTarget(javaVersion.toString())
        // Warnings are defects that have not been triaged yet.
        allWarningsAsErrors = true
    }
}

// JUnit 5 for host unit tests. Configured on the Test task type rather than
// through the Android testOptions DSL so it keeps working across AGP DSL
// changes.
tasks.withType<Test>().configureEach {
    useJUnitPlatform()
}

dependencies {
    implementation(project(":host-core"))

    // The Godot Engine Android library. GameActivity hosts the engine through
    // the GodotHost/GodotFragment contract this artifact provides.
    implementation(libs.godot.android)

    implementation(libs.androidx.activity.ktx)
    implementation(libs.androidx.annotation)
    implementation(libs.androidx.appcompat)
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.core.splashscreen)
    implementation(libs.androidx.datastore.preferences)
    implementation(libs.androidx.fragment.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.window)

    // Play Games Services is declared in the version catalog but deliberately
    // not depended on yet: unlocking a real achievement needs a Play Console
    // games project and a game_ids resource that do not exist. The host talks
    // to an AchievementGateway interface whose only implementation today is a
    // no-op. See docs/release/READINESS.md.

    testImplementation(libs.junit.jupiter)
    testRuntimeOnly(libs.junit.platform.launcher)

    androidTestImplementation(libs.androidx.test.junit)
    androidTestImplementation(libs.androidx.test.runner)
    androidTestImplementation(libs.androidx.test.espresso.core)
}
