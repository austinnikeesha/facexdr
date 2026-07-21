pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            properties.getProperty("flutter.sdk")
                ?: error("flutter.sdk not set in local.properties")
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.1.20" apply false
}

include(":app")

// Flutter plugin subprojects
include(":camera_android")
project(":camera_android").projectDir = file("C:/Users/Administrator/AppData/Local/Pub/Cache/hosted/pub.dev/camera_android-0.10.10/android")

include(":ffmpeg_kit_flutter_full_gpl")
project(":ffmpeg_kit_flutter_full_gpl").projectDir = file("C:/Users/Administrator/AppData/Local/Pub/Cache/hosted/pub.dev/ffmpeg_kit_flutter_full_gpl-6.0.3/android")

include(":flutter_foreground_task")
project(":flutter_foreground_task").projectDir = file("C:/Users/Administrator/AppData/Local/Pub/Cache/hosted/pub.dev/flutter_foreground_task-6.5.0/android")

include(":flutter_plugin_android_lifecycle")
project(":flutter_plugin_android_lifecycle").projectDir = file("C:/Users/Administrator/AppData/Local/Pub/Cache/hosted/pub.dev/flutter_plugin_android_lifecycle-2.0.26/android")

include(":image_picker_android")
project(":image_picker_android").projectDir = file("C:/Users/Administrator/AppData/Local/Pub/Cache/hosted/pub.dev/image_picker_android-0.8.12+21/android")

include(":onnxruntime")
project(":onnxruntime").projectDir = file("C:/Users/Administrator/AppData/Local/Pub/Cache/hosted/pub.dev/onnxruntime-1.4.1/android")

include(":opencv_dart")
project(":opencv_dart").projectDir = file("C:/Users/Administrator/AppData/Local/Pub/Cache/hosted/pub.dev/opencv_dart-1.4.3/android")

include(":package_info_plus")
project(":package_info_plus").projectDir = file("C:/Users/Administrator/AppData/Local/Pub/Cache/hosted/pub.dev/package_info_plus-9.0.1/android")

include(":path_provider_android")
project(":path_provider_android").projectDir = file("C:/Users/Administrator/AppData/Local/Pub/Cache/hosted/pub.dev/path_provider_android-2.2.15/android")

include(":permission_handler_android")
project(":permission_handler_android").projectDir = file("C:/Users/Administrator/AppData/Local/Pub/Cache/hosted/pub.dev/permission_handler_android-12.1.0/android")

include(":shared_preferences_android")
project(":shared_preferences_android").projectDir = file("C:/Users/Administrator/AppData/Local/Pub/Cache/hosted/pub.dev/shared_preferences_android-2.4.7/android")

include(":video_player_android")
project(":video_player_android").projectDir = file("C:/Users/Administrator/AppData/Local/Pub/Cache/hosted/pub.dev/video_player_android-2.7.16/android")

include(":wakelock_plus")
project(":wakelock_plus").projectDir = file("C:/Users/Administrator/AppData/Local/Pub/Cache/hosted/pub.dev/wakelock_plus-1.4.0/android")