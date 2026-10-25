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

    // The release key: build.sh passes its file, and its password from the Mac's Keychain.
    // Without them, as when someone else builds from source, a release build takes the debug key.
    val releaseKey = System.getenv("POMODORO_KEYSTORE")
    signingConfigs {
        if (releaseKey != null) create("release") {
            storeFile = file(releaseKey)
            storePassword = System.getenv("POMODORO_KEY_PASSWORD")
            keyAlias = "pomodoro"
            keyPassword = System.getenv("POMODORO_KEY_PASSWORD")
        }
    }

    buildTypes {
        release {
            // R8 drops the unused parts of Compose, Material and Kotlin: most of the APK.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        }
    }

    buildFeatures {
        compose = true
    }

    dependenciesInfo {
        includeInApk = false
    }
}

// The look comes from the Mac's config.json, the one file all three apps read.
androidComponents {
    onVariants { it.sources.assets?.addStaticSourceDirectory(rootProject.file("../src/config/Resources").path) }
}

dependencies {
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.material3)
    implementation(libs.activity.compose)
    implementation(libs.lifecycle.runtime.compose)
    implementation(libs.camera.camera2)
    implementation(libs.camera.lifecycle)
    implementation(libs.camera.view)
    implementation(libs.zxing.core)
    testImplementation(libs.junit)
    testImplementation(libs.org.json)
}
