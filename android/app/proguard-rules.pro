# ProGuard rules for GoAnime Mobile

# Flutter general keep rules
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Flutter engine JNI methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Google Play Core (deferred components / split install)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# media_kit native libraries
-keep class com.arthenica.** { *; }
-keep class media_kit.** { *; }
-keep class com.alexmercer.** { *; }
-keep class mpv.** { *; }

# sqlite3 FFI (dart:ffi) - keep JNI bridge
-keep class com.pcloudy.** { *; }
-keep class org.sqlite.** { *; }

# webview_flutter
-keep class android.webkit.** { *; }

# cached_network_image / OkHttp
-keep class com.squareup.okhttp.** { *; }
-keep class com.facebook.** { *; }

# SharedPreferences
-keep class android.app.** { *; }
-keep class android.content.** { *; }

# Keep all model classes used for JSON serialization
-keep class com.example.goanime_mobile.** { *; }

# Keep generic signatures and annotations
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
-keepattributes SourceFile, LineNumberTable, RuntimeVisibleAnnotations, RuntimeVisibleParameterAnnotations, RuntimeInvisibleAnnotations, RuntimeInvisibleParameterAnnotations

# Keep Kotlin metadata
-keep class kotlin.Metadata { *; }
