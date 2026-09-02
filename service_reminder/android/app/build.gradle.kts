import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing config, loaded from android/key.properties (never
// committed — see key.properties.example and the README for setup). Falls
// back to debug signing when it's absent, so `flutter build apk --release`
// still works out of the box before you've added your keystore; the
// resulting APK just won't be installable as an update over a
// properly-signed release, and shouldn't be distributed.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.servicereminder.service_reminder"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Play Store identity — cannot change after the first publish.
        applicationId = "com.servicereminder.service_reminder"
        // Pinned to 24: required by flutter_local_notifications (24) and workmanager (23).
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // versionCode/versionName come from pubspec.yaml's `version: x.y.z+n`
        // (the +n is versionCode, x.y.z is versionName). Bump that one line
        // to cut a new release — see the README.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Real release signing once android/key.properties + your keystore
            // are in place; falls back to the debug key otherwise so the
            // build doesn't break for anyone who hasn't set that up yet.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
