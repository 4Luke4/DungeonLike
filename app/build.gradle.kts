import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.android.application)
    // No Kotlin plugin: AGP 9 compiles Kotlin itself and rejects
    // `org.jetbrains.kotlin.android` as incompatible with its DSL. The
    // `kotlin { }` block below is still the correct place to configure the
    // compiler, and is the DSL AGP's own migration guidance points at.
}

// --- Values read from their single sources of truth ---------------------------
//
// Both files are read through the provider API rather than with a plain file
// read, so Gradle records them as configuration inputs: editing the toolchain or
// the version then invalidates the configuration cache instead of being ignored
// until someone notices a stale build.
//
// `layout.settingsDirectory` addresses the repository root without reaching into
// another project's model, which is what keeps this compatible with Gradle's
// isolated-projects mode.
//
// Nothing below may restate a value either file owns; `validate_toolchain.py`
// fails CI if it does.

val toolchainProperties: Map<String, String> =
    providers
        .fileContents(layout.settingsDirectory.file("config/android/toolchain.properties"))
        .asText
        .get()
        .lineSequence()
        .map(String::trim)
        .filter { line -> line.isNotEmpty() && !line.startsWith("#") && !line.startsWith("!") }
        .mapNotNull { line ->
            val separator = line.indexOf('=')
            if (separator <= 0) null else line.take(separator).trim() to line.substring(separator + 1).trim()
        }
        .toMap()

fun toolchain(key: String): String =
    requireNotNull(toolchainProperties[key]) {
        "config/android/toolchain.properties does not declare '$key'"
    }

// `VERSION` holds a bare SemVer string; the `v` prefix is a git tag convention
// only, so nothing here has to strip it.
val applicationVersion: String =
    providers.fileContents(layout.settingsDirectory.file("VERSION")).asText.get().trim()

// versionCode must be a strictly increasing integer, while VERSION is SemVer.
// Deriving it arithmetically keeps the two in lockstep without a second source
// of truth, and the scheme stays monotonic as long as minor and patch stay below
// 100 -- which is asserted rather than assumed.
val semver =
    Regex("""^(\d+)\.(\d+)\.(\d+)$""").matchEntire(applicationVersion)
        ?: error("VERSION must be a bare X.Y.Z SemVer string, found '$applicationVersion'")
val (major, minor, patch) = semver.destructured.toList().map(String::toInt)
require(minor < 100 && patch < 100) {
    "VERSION '$applicationVersion' overflows the versionCode scheme (minor and patch must be < 100)"
}
val applicationVersionCode = major * 10_000 + minor * 100 + patch

android {
    namespace = "com.yuumi.dungeonlike"

    // API 36.1 introduced minor SDK versions, so the platform this compiles
    // against is a (major, minor) pair. AGP exposes a minor for compileSdk only.
    compileSdk = toolchain("sdk.compile").toInt()
    compileSdkMinor = toolchain("sdk.compile.minor").toInt()

    buildToolsVersion = toolchain("build.tools")

    // Pinned even though the project compiles no native code of its own: AGP
    // uses the NDK's tooling to strip and package the engine's prebuilt shared
    // libraries, so an unpinned NDK would silently change how a shipped binary
    // is processed. ADR 0003 couples this revision to the engine's own.
    ndkVersion = toolchain("ndk")

    defaultConfig {
        applicationId = "com.yuumi.dungeonlike"
        minSdk = toolchain("sdk.min").toInt()

        // AGP 9.4.0 models targetSdk as a major release only: TargetSdkSpec
        // offers release(Int) and preview(String), with no minor counterpart
        // (unlike CompileSdkReleaseSpec, which does carry a minor API level).
        // `sdk.target.minor` therefore documents intent and selects the SDK
        // package CI installs; it cannot be asserted here until AGP exposes it.
        targetSdk = toolchain("sdk.target").toInt()

        versionCode = applicationVersionCode
        versionName = applicationVersion

        ndk {
            // 64-bit only, by product requirement (ADR 0003). Assigned from the
            // source of truth so a second ABI cannot be introduced here without
            // first changing the file that CI validates.
            abiFilters += toolchain("abi.filters").split(",").map(String::trim).filter(String::isNotEmpty)
        }

        // The extension level the app is compiled against, surfaced so that code
        // gated on an extension-only API can assert its floor at runtime rather
        // than assuming it.
        buildConfigField("int", "SDK_EXTENSION_FLOOR", toolchain("sdk.extension"))
    }

    buildFeatures {
        buildConfig = true
        // The host draws no game UI (ADR 0002), so none of the view- or
        // Compose-layer features are needed. Disabled explicitly so that
        // enabling one is a visible decision.
        viewBinding = false
        dataBinding = false
        compose = false
    }

    androidResources {
        // Godot's own Android exporter stores `.pck` uncompressed so that the
        // pack can be memory-mapped straight out of the APK; a deflated asset
        // would have to be streamed and decompressed at startup instead.
        noCompress += "pck"

        // `generateLocaleConfig` is deliberately NOT enabled. AGP would derive
        // the supported-language list from the `values-*` directories in `res/`,
        // and this application has none: the engine renders and localizes
        // everything the player sees (ADR 0002), so its translations live in the
        // game data rather than in Android resources. Generating the list would
        // therefore advertise English only. `res/xml/locale_config.xml` is
        // written by hand and declares the five languages the app genuinely
        // ships.
    }

    compileOptions {
        val javaVersion = JavaVersion.toVersion(toolchain("java.version"))
        sourceCompatibility = javaVersion
        targetCompatibility = javaVersion
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }

        release {
            // Required by the release gates in docs/release/READINESS.md. R8 also
            // removes unreachable engine-adjacent code, which matters for a
            // premium download.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )

            // No signing configuration is declared anywhere in the repository.
            // Signing material is injected at release time from protected
            // secrets (THREAT_MODEL.md, boundary 7), so a fork pull request can
            // never reach it.
            isDebuggable = false
        }
    }

    packaging {
        jniLibs {
            // Uncompressed and page-aligned native libraries are loaded directly
            // from the APK with no extraction step. This is also the packaging
            // mode the 16 KB page-size requirement assumes.
            useLegacyPackaging = false
        }
        resources {
            // Duplicate metadata from overlapping dependencies is a packaging
            // failure, not a code problem; drop it rather than failing the build.
            excludes +=
                setOf(
                    "/META-INF/{AL2.0,LGPL2.1}",
                    "/META-INF/DEPENDENCIES",
                    "/META-INF/*.version",
                )
        }
    }

    lint {
        abortOnError = true
        warningsAsErrors = true
        // Dependency sources are not linted. The engine AAR is third-party
        // binary code that this project cannot fix, so failing the build on its
        // findings would produce an unactionable red check -- the exact failure
        // mode that teaches reviewers to ignore CI.
        checkDependencies = false
        // Written so the workflow can upload a report whether the build
        // succeeded or failed.
        htmlReport = true
        xmlReport = true
    }

    testOptions {
        unitTests {
            // Host logic is written to be free of Android framework types
            // precisely so that unit tests need no stubbing. If this ever has to
            // be turned on, that is a signal the logic drifted into the
            // framework and should move back out.
            isReturnDefaultValues = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.fromTarget(toolchain("java.version")))
        // Warnings are the compiler telling us something it could not prove.
        // Treating them as errors keeps that signal from eroding.
        allWarningsAsErrors.set(true)
    }
}

dependencies {
    // The engine. Native code shipped to users, therefore resolved only from
    // MavenCentral and checked against gradle/verification-metadata.xml on every
    // build (THREAT_MODEL.md, boundary 3).
    implementation(libs.godot)

    // GodotActivity extends androidx FragmentActivity, and the engine's POM
    // declares fragment at runtime scope, so it is absent from the compile
    // classpath unless requested explicitly.
    implementation(libs.androidx.fragment)

    testImplementation(libs.junit)
}

// --- Game pack guard ----------------------------------------------------------
//
// The Godot project lives in `game/` and is exported to a single `game.pck`,
// which the host passes to the engine with `--main-pack`. The pack is a build
// output produced by the `engine-pack` job in `.github/workflows/android.yml`
// and is never committed.
//
// Without this guard the application would build perfectly and then fail at
// runtime on a device with an empty screen, which is a far more expensive way to
// discover a missing pack than failing the build.
val gamePackFile = layout.projectDirectory.file("src/main/assets/game.pck").asFile

val verifyGamePack =
    tasks.register("verifyGamePack") {
        description = "Fails early if the exported Godot game pack is missing."
        group = "verification"
        doLast {
            if (!gamePackFile.isFile) {
                throw GradleException(
                    "Missing ${gamePackFile.name}: the Godot game pack has not been exported.\n" +
                        "It is produced by the 'engine-pack' job in .github/workflows/android.yml " +
                        "and is intentionally not committed. Builds run in GitHub Actions only " +
                        "(see the verification policy in AGENTS.md).",
                )
            }
        }
    }

tasks.named("preBuild") {
    dependsOn(verifyGamePack)
}
