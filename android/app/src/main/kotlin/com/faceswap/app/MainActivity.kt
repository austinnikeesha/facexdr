// android/app/src/main/kotlin/com/faceswap/app/MainActivity.kt
package com.faceswap.app

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.faceswap.app/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            when (call.method) {

                "startOverlayService" -> {
                    if (Settings.canDrawOverlays(this)) {
                        val intent = Intent(this, VirtualCameraService::class.java)
                        startForegroundService(intent)
                        result.success(true)
                    } else {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                        result.success(false)
                    }
                }

                "stopOverlayService" -> {
                    val intent = Intent(this, VirtualCameraService::class.java)
                    stopService(intent)
                    result.success(true)
                }

                "updateOverlayFrame" -> {
                    val bytes = call.argument<ByteArray>("frameBytes")
                    if (bytes != null) {
                        val bitmap = BitmapFactory.decodeByteArray(
                            bytes, 0, bytes.size
                        )
                        VirtualCameraService.swappedBitmap = bitmap
                        result.success(true)
                    } else {
                        result.error("NULL_FRAME", "Frame bytes null", null)
                    }
                }

                "isOverlayServiceRunning" -> {
                    result.success(VirtualCameraService.isRunning)
                }

                else -> result.notImplemented()
            }
        }
    }
}