# Project-specific ProGuard rules.
# Firebase Auth must keep persistence classes in release builds.
-keep class com.google.firebase.auth.** { *; }
-keep class com.google.android.gms.internal.firebase-auth-api.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
