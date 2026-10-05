plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.meeplehearth.meeple"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications needs java.time APIs on API < 26.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.meeplehearth.meeple"
        // docs/MOBILE_FLUTTER.md §1: Android 7.0 (API 24) minimum.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Host used by the App Links intent filter (see AndroidManifest.xml).
        manifestPlaceholders["deepLinkHost"] =
            (project.findProperty("meeple.deepLinkHost") as String?) ?: "meeple-hearth.com"
    }

    buildTypes {
        release {
            // Release signing is configured on the CI/release machine via
            // key.properties (never committed). Until then release builds use
            // the debug key so `flutter run --release` works locally.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
