import java.io.File
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasKeystoreProperties = keystorePropertiesFile.exists()

if (hasKeystoreProperties) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

fun keystoreValue(propertyName: String, envName: String): String =
    System.getenv(envName)
        ?.takeIf { it.isNotBlank() }
        ?: keystoreProperties.getProperty(propertyName)
            ?.takeIf { it.isNotBlank() }
        ?: error("Missing '$propertyName' in android/key.properties or env '$envName'")

android {
    namespace = "com.breadbeats.breadbeats_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    signingConfigs {
        if (hasKeystoreProperties) {
            create("release") {
                keyAlias = keystoreValue("keyAlias", "KEYSTORE_KEY_ALIAS")
                keyPassword = keystoreValue("keyPassword", "KEYSTORE_KEY_PASSWORD")
                storeFile = file(keystoreValue("storeFile", "KEYSTORE_STORE_FILE"))
                storePassword = keystoreValue("storePassword", "KEYSTORE_STORE_PASSWORD")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Note: Application ID is explicitly set for this app.
        applicationId = "com.breadbeats.breadbeats_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = if (hasKeystoreProperties) {
                signingConfigs.getByName("release")
            } else {
                // Allows local release runs before key setup.
                signingConfigs.getByName("debug")
            }
            ndk {
                abiFilters += "arm64-v8a"
            }
        }
    }
}

tasks.register("renameReleaseApk") {
    doLast {
        val outputDir = layout.buildDirectory.dir("outputs/flutter-apk").get().asFile
        val arm64Apk = File(outputDir, "app-arm64-v8a-release.apk")
        val universalApk = File(outputDir, "app-release.apk")
        val sourceApk = when {
            arm64Apk.exists() && universalApk.exists() -> {
                if (arm64Apk.lastModified() >= universalApk.lastModified()) arm64Apk else universalApk
            }
            arm64Apk.exists() -> arm64Apk
            universalApk.exists() -> universalApk
            else -> null
        }
        val targetApk = File(outputDir, "bbmobile.apk")

        if (sourceApk != null) {
            sourceApk.copyTo(targetApk, overwrite = true)
            println("Release APK copy created: ${targetApk.absolutePath} (source: ${sourceApk.name})")
        } else {
            println(
                "Release APK not found. Checked: ${arm64Apk.absolutePath}, ${universalApk.absolutePath}",
            )
        }
    }
}

tasks.configureEach {
    if (name == "assembleRelease" || name == "packageRelease") {
        finalizedBy("renameReleaseApk")
    }
}

flutter {
    source = "../.."
}
