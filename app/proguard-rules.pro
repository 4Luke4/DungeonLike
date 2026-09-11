# R8 configuration for DungeonLike.
#
# The Godot Android library ships no consumer rules of its own -- the published
# AAR contains no `proguard.txt` -- so every keep rule the engine needs must be
# declared here. This is not optional hardening: the engine reaches into JVM code
# from native code and from GDScript by name, and R8 cannot see either edge.
# Without these rules a release build shrinks perfectly and then fails at
# runtime, which is the most expensive moment to discover it.

# --- Engine JNI surface ------------------------------------------------------
#
# `GodotLib` is the JNI bridge: its methods are resolved from native code by
# name and signature, so neither they nor the class may be renamed or removed.
-keep class org.godotengine.godot.GodotLib { *; }

# Native methods are invoked by the runtime through their declared names.
-keepclasseswithmembernames class * {
    native <methods>;
}

# `@UsedByGodot` marks JVM methods that GDScript calls by name through a plugin
# singleton. R8 sees no caller for them, so it would otherwise inline or strip
# them. The annotation itself must survive too, because the engine reads it
# reflectively when registering a plugin's methods.
-keep @interface org.godotengine.godot.plugin.UsedByGodot
-keepclassmembers class * {
    @org.godotengine.godot.plugin.UsedByGodot <methods>;
}

# Plugins are discovered and instantiated reflectively by the engine's registry,
# which needs the constructor that takes the engine instance.
-keep class * extends org.godotengine.godot.plugin.GodotPlugin {
    public <init>(org.godotengine.godot.Godot);
}

# Signal metadata is read by name when a plugin registers its signals.
-keep class org.godotengine.godot.plugin.SignalInfo { *; }

# --- Host bridge -------------------------------------------------------------
#
# The entire host-to-engine surface. Kept explicitly rather than relying on the
# annotation rule alone, so that the bridge's name -- which GDScript looks up as
# an engine singleton -- survives as well as its members.
-keep class com.yuumi.dungeonlike.host.HostBridge { *; }

# --- Diagnostics -------------------------------------------------------------
#
# Retain the attributes needed to deobfuscate a crash report with the mapping
# file, which is a release gate in docs/release/READINESS.md.
-keepattributes SourceFile,LineNumberTable,Signature,*Annotation*

# Rewrite the source file name so the original paths are not shipped, while
# still allowing the mapping file to resolve stack traces.
-renamesourcefileattribute SourceFile
