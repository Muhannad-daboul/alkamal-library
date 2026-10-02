# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.embedding.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Firebase Crashlytics
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# Firebase Messaging
-keep class com.google.firebase.messaging.** { *; }

# Cloud Firestore models — keep field names for serialization
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName <fields>;
    @com.google.firebase.firestore.PropertyName <methods>;
}

# Geolocator
-keep class com.baseflow.geolocator.** { *; }

# Video Player
-keep class com.google.android.exoplayer.** { *; }
-keep class com.google.android.exoplayer2.** { *; }

# pdfx (PDFium)
-keep class com.shockwave.** { *; }
-keep class io.legere.pdfiumandroid.** { *; }

# File Picker
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# Image Picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# url_launcher
-keep class io.flutter.plugins.urllauncher.** { *; }

# Cloud Functions
-keep class com.google.firebase.functions.** { *; }

# Keep enum names (needed for some plugins)
-keepclassmembers enum * { *; }

# Keep Parcelable
-keep class * implements android.os.Parcelable {
  public static final android.os.Parcelable$Creator *;
}

# Play Core Split (referenced by Flutter embedding but not used at runtime)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
