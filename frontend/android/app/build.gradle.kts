import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.apsbrat_frontend"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    dependencies {
        coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.apsbrat_frontend"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Release signing: create android/key.properties (never commit it) with
    //   storeFile=<path to your .jks>  storePassword=...  keyAlias=...  keyPassword=...
    // Without it a release build is signed with the DEBUG key: fine for trying
    // `flutter run --release` locally, but the Play Store will reject it.
    val keyProps = Properties()
    val keyFile = rootProject.file("key.properties")
    if (keyFile.exists()) {
        keyFile.inputStream().use { keyProps.load(it) }
    }

    signingConfigs {
        if (keyFile.exists()) {
            create("release") {
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword")
                storeFile = file(keyProps.getProperty("storeFile"))
                storePassword = keyProps.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keyFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                logger.warn("WARNING: android/key.properties not found, signing the release build with the DEBUG key")
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
