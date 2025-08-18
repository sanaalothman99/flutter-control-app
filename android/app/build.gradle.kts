plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // غيّري الـ namespace لمعرّفك
    namespace = "com.sana.fluttercontrol"

    // هذه القيم يوفّرها Flutter Gradle plugin
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        // نفس الـ namespace عادةً
        applicationId = "com.sana.fluttercontrol"

        // ✅ صيغة Kotlin DSL الصحيحة (بدلاً من minSdkVersion/targetSdkVersion)
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion

        // يقرأان من gradle.properties (flutter.versionCode / flutter.versionName)
        versionCode = project.property("flutter.versionCode").toString().toInt()
        versionName = project.property("flutter.versionName").toString()

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
