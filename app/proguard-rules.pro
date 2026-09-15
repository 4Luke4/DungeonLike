# R8 configuration for release builds.
#
# Only rules whose removal would actually break the application belong here. A
# speculative -keep costs shrinking and obfuscation for no benefit, so each rule
# below states what would break without it.

# The Godot Android library resolves engine entry points and plugin methods
# reflectively through JNI. Obfuscating or removing them breaks the engine at
# startup with no compile-time warning.
-keep class org.godotengine.godot.** { *; }
-keep class * extends org.godotengine.godot.plugin.GodotPlugin { *; }

# Methods exposed to GDScript are looked up by name at runtime: GDScript calls
# them by the exact Kotlin method name, so renaming them breaks every call site
# in the game with no build error.
-keepclasseswithmembers class * {
    @org.godotengine.godot.plugin.UsedByGodot <methods>;
}

# Signal names are resolved by string as well.
-keepclassmembers class * {
    @org.godotengine.godot.plugin.UsedByGodot *;
}

# Keep the source file and line numbers in stack traces, and rename the source
# file attribute so that traces stay useful without leaking the original file
# layout. Without this a crash report from a release build is unreadable.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
