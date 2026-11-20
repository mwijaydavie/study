plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val smokeInstall = providers.gradleProperty("studydeskSmoke").orNull == "true"

android {
    namespace = "tz.altraware.studydesk"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    androidResources {
        // The greeting player opens a seekable raw-resource descriptor.
        noCompress += "mp3"
    }

    defaultConfig {
        applicationId = "tz.altraware.studydesk"
        manifestPlaceholders["studyDeskLabel"] = "StudyDesk"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    if (smokeInstall) {
        buildTypes.named("debug") {
            // Test beside an installed StudyDesk with a different signing key.
            applicationIdSuffix = ".smoke"
            manifestPlaceholders["studyDeskLabel"] = "StudyDesk Test"
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.core:core:1.13.1") // private file handoff via FileProvider
    testImplementation("junit:junit:4.13.2")
}
