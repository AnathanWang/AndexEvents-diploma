plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.andexevents"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.andexevents"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26  // Yandex MapKit requires API 26+
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Manifest placeholder for Yandex MapKit API key.
        // IMPORTANT: Do NOT hardcode or commit the actual API key into the repository.
        // Put the real key in a git-ignored file (e.g., local.properties) or set it as a CI secret:
        //   YANDEX_MAPKIT_API_KEY=your_real_key_here
        // The placeholder below reads the key from a project property (local.properties or --project-prop)
        // and falls back to an empty string if not provided.
        manifestPlaceholders["YANDEX_MAPKIT_API_KEY"] = project.findProperty("YANDEX_MAPKIT_API_KEY") ?: ""
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
