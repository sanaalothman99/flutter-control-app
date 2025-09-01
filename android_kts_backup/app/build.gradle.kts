plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")

}

android {
    // غيّري الـ namespace لمعرّفك
    namespace = "com.sana.fluttercontrol"


    // هذه القيم يوفّرها Flutter Gradle plugin
    compileSdk = 34
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        // نفس الـ namespace عادةً
        applicationId = "com.sana.fluttercontrol"

        // ✅ صيغة Kotlin DSL الصحيحة (بدلاً من minSdkVersion/targetSdkVersion)
        minSdk = 23
        targetSdk =34

        // يقرأان من gradle.properties (flutter.versionCode / flutter.versionName)
        versionCode = 1
        versionName ="1.0"

        multiDexEnabled = true
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
}

flutter {
    source = "../.."
}
