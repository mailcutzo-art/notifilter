plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}
android {
    namespace = "art.mailcutzo.notifilter"
    compileSdk = 36
    defaultConfig {
        applicationId = "art.mailcutzo.notifilter"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "0.1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }
    signingConfigs.getByName("debug") {
        System.getenv("NOTIFILTER_DEBUG_KEYSTORE")?.let { storeFile = file(it) }
    }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
    kotlinOptions { jvmTarget = "17" }
}
flutter { source = "../.." }
dependencies { testImplementation("junit:junit:4.13.2") }
