import java.util.Properties

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
        // keystore 與密碼都不進版控（repo 是 public）：本地放 android/app/{dneko.keystore,
        // key.properties}，CI 由 secrets KEYSTORE_B64 / KEY_PROPERTIES 還原到同一路徑。
        // 檔名不叫 debug.keystore：這是正式 release 鑰，叫 debug 會在查問題時把人帶偏（與 dHealth 對齊）。
        // 2026-11-09 換鑰：舊 dneko 共用鑰的密碼曾進 git 歷史（公開 repo，歷史改不掉）→ 視為作廢。
        create("release") {
            val propsFile = file("key.properties")
            if (propsFile.exists()) {
                val props = Properties().apply { propsFile.inputStream().use { load(it) } }
                storeFile = file(props.getProperty("storeFile"))
                storePassword = props.getProperty("storePassword")
                keyAlias = props.getProperty("keyAlias")
                keyPassword = props.getProperty("keyPassword")
            }
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
