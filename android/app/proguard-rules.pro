# Keep Flutter framework classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Firebase / Google Play Services safe defaults
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class androidx.lifecycle.** { *; }

# Retain JSON model classes used via reflection (if any)
-keepclassmembers class ** implements java.io.Serializable {
    private static final long serialVersionUID;
    static final long serialVersionUID;
}
