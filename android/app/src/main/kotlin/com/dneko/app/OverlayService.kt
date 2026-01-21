package com.dneko.app

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.PixelFormat
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.WindowManager
import android.widget.ImageView

class OverlayService(private val context: Context) {
    private var windowManager: WindowManager? = null
    private var overlayView: ImageView? = null
    private val TAG = "OverlayService"

    @SuppressLint("InflateParams")
    fun showOverlay() {
        Log.d(TAG, "showOverlay called")
        
        if (overlayView != null) {
            Log.d(TAG, "Overlay already showing, removing first")
            removeOverlay()
        }

        windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

        // Create ImageView for the overlay
        overlayView = ImageView(context)
        
        // Load the image from assets
        try {
            Log.d(TAG, "Attempting to load dneko.png from assets")
            val inputStream = context.assets.open("flutter_assets/assets/dneko.png")
            val bitmap = android.graphics.BitmapFactory.decodeStream(inputStream)
            
            if (bitmap != null) {
                Log.d(TAG, "Bitmap loaded successfully: ${bitmap.width}x${bitmap.height}")
                overlayView?.setImageBitmap(bitmap)
            } else {
                Log.e(TAG, "Bitmap is null after decoding")
                return
            }
            inputStream.close()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load image: ${e.message}", e)
            return
        }

        // Set up window layout parameters
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        )

        params.gravity = Gravity.CENTER
        params.x = 0
        params.y = 0

        try {
            // Add the view to window
            Log.d(TAG, "Adding overlay view to window")
            windowManager?.addView(overlayView, params)
            Log.d(TAG, "Overlay view added successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to add overlay view: ${e.message}", e)
            return
        }

        // Remove after 10 seconds
        Handler(Looper.getMainLooper()).postDelayed({
            Log.d(TAG, "Removing overlay after 10 seconds")
            removeOverlay()
        }, 10000)
    }

    private fun removeOverlay() {
        overlayView?.let {
            try {
                windowManager?.removeView(it)
                Log.d(TAG, "Overlay removed")
            } catch (e: Exception) {
                Log.e(TAG, "Error removing overlay: ${e.message}", e)
            }
            overlayView = null
        }
    }
}
