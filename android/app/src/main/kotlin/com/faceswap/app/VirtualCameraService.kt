// android/app/src/main/kotlin/com/faceswap/app/VirtualCameraService.kt
package com.faceswap.app

import android.app.*
import android.content.Intent
import android.graphics.*
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.*
import android.view.*
import android.widget.ImageView
import androidx.core.app.NotificationCompat

class VirtualCameraService : Service() {

    companion object {
        const val CHANNEL_ID = "FaceSwapOverlay"
        const val NOTIFICATION_ID = 1001
        var swappedBitmap: Bitmap? = null
        var isRunning = false
    }

    private var windowManager: WindowManager? = null
    private var overlayView: ImageView? = null
    private val handler = Handler(Looper.getMainLooper())

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        setupOverlayWindow()
    }

    private fun setupOverlayWindow() {
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager

        overlayView = ImageView(this).apply {
            scaleType = ImageView.ScaleType.FIT_XY
        }

        val params = WindowManager.LayoutParams(
            480, 640,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 0
            y = 100
        }

        windowManager?.addView(overlayView, params)
        startFrameUpdater()
    }

    private fun startFrameUpdater() {
        handler.post(object : Runnable {
            override fun run() {
                swappedBitmap?.let { bmp ->
                    overlayView?.setImageBitmap(bmp)
                }
                handler.postDelayed(this, 33) // ~30 FPS
            }
        })
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Face Swap Overlay",
                NotificationManager.IMPORTANCE_LOW
            )
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("FaceSwap Active")
            .setContentText("Face swapping is running in background")
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        isRunning = false
        handler.removeCallbacksAndMessages(null)
        overlayView?.let { windowManager?.removeView(it) }
        super.onDestroy()
    }
}