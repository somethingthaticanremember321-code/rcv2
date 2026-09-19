# Proguard / R8 rules for DashTally

# ML Kit Text Recognition
-dontwarn com.google.mlkit.vision.text.**
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-keep class com.google.mlkit.vision.text.** { *; }

# Google Play Services
-dontwarn com.google.android.gms.**
-keep class com.google.android.gms.** { *; }

# PostHog Telemetry
-dontwarn com.posthog.**
-keep class com.posthog.** { *; }
