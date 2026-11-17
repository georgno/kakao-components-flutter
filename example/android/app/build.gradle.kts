plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "io.github.georgno.kakao_showcase"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "io.github.georgno.kakao_showcase"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // One fixed key for every showcase build (local and CI), so a newer build
    // installs over an older one. It is a public development key: this app is
    // a showcase, never a store release.
    signingConfigs {
        create("showcase") {
            storeFile = file("showcase-dev.jks")
            storePassword = "kakao-showcase"
            keyAlias = "showcase"
            keyPassword = "kakao-showcase"
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("showcase")
        }
        release {
            signingConfig = signingConfigs.getByName("showcase")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // FileProvider, to hand a downloaded update to the installer.
    implementation("androidx.core:core-ktx:1.13.1")
}
