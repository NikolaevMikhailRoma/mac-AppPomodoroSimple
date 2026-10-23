plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

// Version and id come from the repository's app.json, shared with the Mac app:
// one release, one version for both.
@Suppress("UNCHECKED_CAST")
val appJson = groovy.json.JsonSlurper().parse(rootProject.file("../app.json")) as Map<String, String>
val appVersion = appJson.getValue("version")

android {
    namespace = "com.nikolaev.pomodoro"
    // Current AndroidX needs compileSdk 37; it does not raise minSdk.
    compileSdk = 37

    defaultConfig {
        applicationId = appJson.getValue("bundleIdentifier")
        minSdk = 26
        targetSdk = 36
        versionName = appVersion
        // 0.2.0 → 200, 1.4.12 → 10412: grows with every release, as Android requires.
        versionCode = appVersion.split(".").map(String::toInt).fold(0) { code, part -> code * 100 + part }
        // Both the emulator and the Motorola are arm64; other ABIs only add weight.
        ndk { abiFilters += "arm64-v8a" }
    }

    // Library strings (accessibility labels and the like) only in the languages the phone uses.
    androidResources { localeFilters += listOf("en", "ru") }

    buildTypes {
        release {
            // R8 drops the unused parts of Compose, Material and Kotlin: most of the APK.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
            // The same key as debug builds, so either installs over the other without losing data.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    buildFeatures {
        compose = true
    }

    dependenciesInfo {
        includeInApk = false
    }
}

dependencies {
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.material3)
    implementation(libs.activity.compose)
    implementation(libs.lifecycle.runtime.compose)
    testImplementation(libs.junit)
    testImplementation(libs.org.json)
}
