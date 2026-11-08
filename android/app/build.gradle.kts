plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.dneko.app"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.dneko.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // 只打 arm64：通用 APK 會多塞 armeabi-v7a 與 x86_64 兩份引擎庫（+30MB）。
        // 與 CI 的 --target-platform android-arm64 一致；要裝舊 32 位機或 x86 模擬器時再放開。
        ndk {
            abiFilters += listOf("arm64-v8a")
        }
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // 固定簽名：之前 release 用 debug key，但 CI 每台 runner 的 debug.keystore
        // 都是現生的一次性金鑰 → 每版簽名不同，只能砍掉重裝。
        // keystore 本體不進版控：本地在 android/app/debug.keystore，CI 由
        // secret KEYSTORE_B64 解码到同一路徑。
        create("release") {
            storeFile = file("debug.keystore")
            storePassword = "iu6cv1o8k5b7re0d"
            keyAlias = "dneko"
            keyPassword = "iu6cv1o8k5b7re0d"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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
