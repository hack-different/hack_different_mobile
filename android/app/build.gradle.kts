import java.util.Properties

plugins {
    id("com.android.application")
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
}

val localProperties = Properties().apply {
    rootProject.file("local.properties").takeIf { it.exists() }?.inputStream()?.use(::load)
}

fun setting(name: String): String? =
    providers.gradleProperty("hackdifferent.$name").orNull ?: localProperties.getProperty("hackdifferent.$name")

// Release is signed with a Play upload key kept outside the repository. Google Play re-signs what it ships with the
// app signing key it manages, so the upload key can be shared with other apps: by default this reads
// `hackdifferent.upload.*`, then `hotmess.upload.*` (storeFile, storePassword, keyAlias, keyPassword), from
// android/local.properties or from the properties file named by `hackdifferent.upload.properties`
// (e.g. Hot Mess's local.properties on the release Mac).
val uploadProperties = Properties().apply {
    putAll(localProperties)
    setting("upload.properties")
        ?.let { file(it.replaceFirst(Regex("^~"), System.getProperty("user.home"))) }
        ?.takeIf { it.exists() }
        ?.inputStream()?.use(::load)
}

fun uploadSecret(name: String): String =
    providers.gradleProperty("hackdifferent.upload.$name").orNull
        ?: uploadProperties.getProperty("hackdifferent.upload.$name")
        ?: uploadProperties.getProperty("hotmess.upload.$name")
        ?: ""

// Play needs a new, higher version code for every upload: pass -Phackdifferent.versionCode=N (or BUILD_NUMBER).
val appVersionCode = (setting("versionCode") ?: System.getenv("BUILD_NUMBER"))?.toIntOrNull() ?: 1

data class BuildEnvironment(
    val name: String,
    val apiBaseUrl: String,
    val audienceHost: String,
    val audienceId: String,
    val facebookAppId: String,
    val appleServicesId: String,
    val audienceKitEnvironment: String,
    val displayName: String,
)

val environments = mapOf(
    "debug" to BuildEnvironment(
        name = "debug",
        apiBaseUrl = "https://api.audiencekit.com",
        audienceHost = "hack-different.admin.audiencekit.com",
        audienceId = "2416ce6c-f28a-4460-8b6f-840f3c0027c9",
        facebookAppId = "713525445368431",
        appleServicesId = "com.hackdifferent.app",
        audienceKitEnvironment = "production",
        displayName = "Hack Different",
    ),
    "staging" to BuildEnvironment(
        name = "staging",
        apiBaseUrl = "https://api.next.audiencekit.com",
        audienceHost = "hack-different.admin.next.audiencekit.com",
        audienceId = "2416ce6c-f28a-4460-8b6f-840f3c0027c9",
        facebookAppId = "713525445368431",
        appleServicesId = "com.hackdifferent.app.next",
        audienceKitEnvironment = "staging",
        displayName = "Hack Different Next",
    ),
    "release" to BuildEnvironment(
        name = "release",
        apiBaseUrl = "https://api.audiencekit.com",
        audienceHost = "hack-different.admin.audiencekit.com",
        audienceId = "2416ce6c-f28a-4460-8b6f-840f3c0027c9",
        facebookAppId = "713525445368431",
        appleServicesId = "com.hackdifferent.app",
        audienceKitEnvironment = "production",
        displayName = "Hack Different",
    ),
)

android {
    namespace = "com.hackdifferent.app"
    compileSdk = 37

    defaultConfig {
        applicationId = "com.hackdifferent.app"
        minSdk = 26
        targetSdk = 36
        versionCode = appVersionCode
        versionName = "1.0.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    val uploadStoreFile = uploadSecret("storeFile")
    if (uploadStoreFile.isNotEmpty()) {
        signingConfigs.create("upload") {
            storeFile = file(uploadStoreFile.replaceFirst(Regex("^~"), System.getProperty("user.home")))
            storePassword = uploadSecret("storePassword")
            keyAlias = uploadSecret("keyAlias").ifEmpty { "upload" }
            keyPassword = uploadSecret("keyPassword").ifEmpty { uploadSecret("storePassword") }
        }
    }

    buildTypes {
        getByName("debug") {
            isMinifyEnabled = false
        }
        getByName("release") {
            signingConfigs.findByName("upload")?.let { signingConfig = it }
            // R8 shrinks and obfuscates (Play flags apps with little obfuscation); retrace reports with mapping.txt.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
        create("staging") {
            initWith(getByName("release"))
            applicationIdSuffix = ".next"
            versionNameSuffix = "-next"
            signingConfig = signingConfigs.getByName("debug")
            matchingFallbacks += listOf("release")
        }
    }

    buildTypes.configureEach {
        val env = environments.getValue(name)
        buildConfigField("String", "API_BASE_URL", "\"${env.apiBaseUrl}\"")
        buildConfigField("String", "AUDIENCE_HOST", "\"${env.audienceHost}\"")
        buildConfigField("String", "AUDIENCE_ID", "\"${env.audienceId}\"")
        buildConfigField("String", "FACEBOOK_APP_ID", "\"${env.facebookAppId}\"")
        buildConfigField("String", "APPLE_SERVICES_ID", "\"${env.appleServicesId}\"")
        buildConfigField("String", "AUDIENCEKIT_ENVIRONMENT", "\"${env.audienceKitEnvironment}\"")
        resValue("string", "app_name", env.displayName)
    }

    buildFeatures {
        compose = true
        buildConfig = true
        resValues = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
    }
}

dependencies {
    implementation(project(":core"))
    implementation(libs.audiencekit.android)
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.kotlinx.serialization.json)

    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.androidx.browser)

    implementation(libs.compose.ui)
    implementation(libs.compose.foundation)
    implementation(libs.compose.material3)
    implementation(libs.compose.material.icons)
    implementation(libs.compose.ui.tooling.preview)
    debugImplementation(libs.compose.ui.tooling)

    implementation(libs.coil.compose)
    implementation(libs.coil.network.okhttp)
    implementation(libs.okhttp)
    implementation(libs.zxing.core)

    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.test.runner)
    androidTestImplementation(libs.androidx.test.junit)
}
