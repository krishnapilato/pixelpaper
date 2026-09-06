# Flutter engine
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class plugins.flutter.io.** { *; }

# Google Play split/deferred component classes are not bundled
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Syncfusion PDF reflects over its own types while saving documents
-keep class com.syncfusion.** { *; }
-dontwarn com.syncfusion.**

# Only the Latin recogniser is bundled; the plugin still references the other
# scripts, so R8 must be told they are intentionally absent.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ML Kit and Play Services find their implementations by *name* at runtime:
# dynamite modules loaded from the Play Services APK, component registrars
# listed in the manifest, members tagged @KeepName/@KeepForSdk. R8 renames
# them, the lookup comes back null, and the failure surfaces far from the
# cause — a NullPointerException inside Objects.requireNonNull the moment the
# scanner or the text recogniser is constructed. Debug works, release does
# not, which is the signature of exactly this problem.
#
# Verified on device: without these rules "Scansiona" and "Testo" both fail in
# a release build and work in debug.
-keep class com.google.mlkit.** { *; }
-keep interface com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-keep interface com.google.android.gms.** { *; }
-keep class com.google.android.odml.** { *; }
-keepnames class com.google.android.gms.** { *; }
-keepclassmembers class * {
    @com.google.android.gms.common.annotation.KeepName *;
}

# The plugins' own bridge classes, for the same reason.
-keep class com.google_mlkit_commons.** { *; }
-keep class com.google_mlkit_document_scanner.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }

# Annotations and generic signatures must survive: the libraries above read
# them back at runtime, and R8 drops them by default.
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
