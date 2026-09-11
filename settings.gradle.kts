// DungeonLike -- Gradle settings.
//
// This file is also where the Android toolchain reaches the build. Every SDK,
// NDK, ABI and Java value is owned by `config/android/toolchain.properties`
// (ADR 0003), so the build reads that file instead of restating any of it;
// `scripts/validate_toolchain.py` fails CI if a build script hardcodes a value
// the properties file owns.

pluginManagement {
    repositories {
        // Content filters bind each artifact coordinate to the repository that
        // is actually entitled to serve it. Without them, Gradle asks every
        // repository for every artifact, so a hostile or misconfigured mirror
        // gets an opportunity to answer first with a substitute.
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    // A project that declares its own repositories bypasses the repository
    // policy above, which would silently defeat both the content filters and
    // dependency verification. Fail the build instead of tolerating it.
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
    }
}

rootProject.name = "DungeonLike"

include(":app")

// --- Note on toolchain propagation ------------------------------------------
//
// Modules read `config/android/toolchain.properties` and `VERSION` directly,
// through the provider API, so that Gradle tracks both files as configuration
// inputs and a change to either invalidates the configuration cache.
//
// Injecting the parsed values from here was considered and rejected:
// `GradleLifecycle.beforeProject` takes an isolated action, which adds a
// serialization constraint and an extra indirection to buy nothing while there
// is a single module.
//
// A dedicated `build-logic` included build is the conventional home for shared
// build configuration once several modules need it. With one module it would be
// the premature abstraction that AGENTS.md forbids; the trade-off and the
// trigger for revisiting it are recorded in ADR 0005.
