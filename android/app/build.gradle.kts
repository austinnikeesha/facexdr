plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.faceswap.app"
    compileSdk = 34
    ndkVersion = "26.1.10909125"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.faceswap.app"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
        multiDexEnabled = true
        ndkVersion = "26.1.10909125"
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    packaging {
        resources {
            pickFirsts += listOf(
                "**/libonnxruntime.so",
                "**/libopencv_java4.so",
                "**/libc++_shared.so"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
    implementation("androidx.core:core:1.13.1")
    implementation("androidx.core:core-ktx:1.13.1")
    implementation(project(":camera_android"))
    implementation(project(":ffmpeg_kit_flutter_full_gpl"))
    implementation(project(":flutter_foreground_task"))
    implementation(project(":flutter_plugin_android_lifecycle"))
    implementation(project(":image_picker_android"))
    implementation(project(":onnxruntime"))
    implementation(project(":opencv_dart"))
    implementation(project(":package_info_plus"))
    implementation(project(":path_provider_android"))
    implementation(project(":permission_handler_android"))
    implementation(project(":shared_preferences_android"))
    implementation(project(":video_player_android"))
    implementation(project(":wakelock_plus"))
}