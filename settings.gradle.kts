// Settings for the DungeonLike build.
//
// Repository declarations live here and only here: FAIL_ON_PROJECT_REPOS makes
// it an error for a module to add its own repository, so the set of hosts this
// build will download code from is fixed in one reviewable place.

pluginManagement {
    repositories {
        // Android Gradle plugin and Google-published libraries.
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
    repositoriesMode = RepositoriesMode.FAIL_ON_PROJECT_REPOS
    repositories {
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        // The Godot Engine Android library is published to Maven Central.
        mavenCentral()
    }
}

rootProject.name = "DungeonLike"

// :app        the Android application and the only module that ships a manifest
// :host-core  platform-independent host logic, unit-tested without a device
include(":app")
include(":host-core")
