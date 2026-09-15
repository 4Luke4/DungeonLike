import java.util.Properties

// Root build script.
//
// It does three things and deliberately nothing else:
//   1. applies security overrides to the build's own classpath,
//   2. loads the toolchain and version sources of truth and exposes them to the
//      modules, and
//   3. fails the build when those sources of truth disagree with each other.
//
// No module configuration happens here. A `subprojects { }` block would make
// each module's build file an incomplete description of that module.

buildscript {
    // Security overrides for vulnerable transitive BUILD tooling, applied to the
    // buildscript classpath — the plugins and their dependencies, not the
    // libraries that ship inside the application.
    //
    // The file is read with plain file I/O rather than the provider API because
    // this block is evaluated before a project's provider factory exists. The
    // list is normally empty; see config/build-tool-security.versions for the
    // format and the rules for adding and retiring an entry.
    val overridesFile = file("config/build-tool-security.versions")
    val overrides: Map<String, String> = if (overridesFile.isFile) {
        overridesFile.readLines()
            .map { it.substringBefore('#').trim() }
            .filter { it.isNotEmpty() && it.contains('=') }
            .associate { line ->
                line.substringBefore('=').trim() to line.substringAfter('=').trim()
            }
    } else {
        emptyMap()
    }

    if (overrides.isNotEmpty()) {
        configurations.classpath {
            resolutionStrategy.eachDependency {
                val coordinates = "${requested.group}:${requested.name}"
                overrides[coordinates]?.let { forced ->
                    useVersion(forced)
                    because("security override declared in config/build-tool-security.versions")
                }
            }
        }
    }
}

plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.android.library) apply false
}

// --- Sources of truth --------------------------------------------------------

// The Android toolchain. Modules read these values through
// `rootProject.extra`; nothing restates them.
val toolchain: Map<String, String> = Properties().apply {
    file("config/android/toolchain.properties").inputStream().use { load(it) }
}.entries.associate { (key, value) -> key.toString() to value.toString() }

// The application version. VERSION is authoritative; versionName is taken from
// it verbatim and versionCode is derived so that the two can never disagree and
// so that a release never needs a second number to be remembered.
val versionName: String = file("VERSION").readText().trim()
val semver = Regex("""^(\d+)\.(\d+)\.(\d+)$""").matchEntire(versionName)
    ?: error("VERSION must contain a semantic version such as 1.2.3, found: '$versionName'")
val (major, minor, patch) = semver.destructured
val versionCode: Int = major.toInt() * 10_000 + minor.toInt() * 100 + patch.toInt()

extra["dungeonlike.toolchain"] = toolchain
extra["dungeonlike.versionName"] = versionName
extra["dungeonlike.versionCode"] = versionCode

// --- Consistency gates -------------------------------------------------------

// The version catalog mirrors the Android Gradle plugin version so that the
// plugins {} block can resolve it, but config/android/toolchain.properties owns
// it. If the mirror drifts, the build stops here rather than producing a binary
// built with a toolchain nobody documented.
val declaredAgp = toolchain.getValue("build.androidGradlePlugin")
val catalogAgp = libs.versions.androidGradlePlugin.get()
check(declaredAgp == catalogAgp) {
    "Android Gradle plugin version mismatch: config/android/toolchain.properties declares " +
        "$declaredAgp but gradle/libs.versions.toml declares $catalogAgp."
}

// The Godot Android library must be the exact build whose editor and export
// templates the CI pipeline downloads, otherwise the engine that exports the
// game pack and the engine that loads it are different builds.
val declaredGodot = toolchain.getValue("godot.version")
val catalogGodot = libs.versions.godot.get()
check(declaredGodot == catalogGodot) {
    "Godot version mismatch: config/android/toolchain.properties declares $declaredGodot " +
        "but gradle/libs.versions.toml declares $catalogGodot."
}

tasks.register("toolchainReport") {
    group = "help"
    description = "Prints the resolved toolchain, application version and version code."

    // Values are read at configuration time so the task body stays compatible
    // with the configuration cache.
    val report = buildString {
        appendLine("DungeonLike $versionName (versionCode $versionCode)")
        toolchain.toSortedMap().forEach { (key, value) -> appendLine("  $key = $value") }
    }
    doLast { println(report) }
}
