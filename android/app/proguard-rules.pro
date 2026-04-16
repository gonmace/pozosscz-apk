# Flutter — mantener clases de embedding
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }

# Firebase / Google Services
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# flutter_foreground_task
-keep class com.pravera.flutter_foreground_task.** { *; }

# webview_flutter
-keep class io.flutter.plugins.webviewflutter.** { *; }

# Google Play Core (clases referenciadas por Flutter embedding — no usamos deferred components)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Kotlin coroutines
-dontwarn kotlinx.coroutines.**

# Evitar que R8 elimine clases con reflection
-keepattributes *Annotation*
-keepattributes Signature
