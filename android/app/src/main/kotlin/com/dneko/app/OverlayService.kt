package com.dneko.app

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PixelFormat
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager

class OverlayService(private val context: Context) {
    private var windowManager: WindowManager? = null
    private var overlayView: NekoView? = null
    private val TAG = "OverlayService"

    @SuppressLint("InflateParams")
    fun showOverlay() {
        Log.d(TAG, "showOverlay called")

        if (overlayView != null) {
            Log.d(TAG, "Overlay already showing, removing first")
            removeOverlay()
        }

        windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

        // Create NekoView for the overlay
        overlayView = NekoView(context)

        // Load the image from assets
        try {
            Log.d(TAG, "Attempting to load dneko.png from assets")
            val inputStream = context.assets.open("flutter_assets/assets/dneko.png")
            val bitmap = BitmapFactory.decodeStream(inputStream)

            if (bitmap != null) {
                Log.d(TAG, "Bitmap loaded successfully: ${bitmap.width}x${bitmap.height}")
                overlayView?.setBitmap(bitmap)
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
        val params =
                WindowManager.LayoutParams(
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
        Handler(Looper.getMainLooper())
                .postDelayed(
                        {
                            Log.d(TAG, "Removing overlay after 10 seconds")
                            removeOverlay()
                        },
                        10000
                )
    }

    private fun removeOverlay() {
        overlayView?.let {
            try {
                it.cleanup()
                windowManager?.removeView(it)
                Log.d(TAG, "Overlay removed")
            } catch (e: Exception) {
                Log.e(TAG, "Error removing overlay: ${e.message}", e)
            }
            overlayView = null
        }
    }
}

// Custom Canvas View for drawing the Neko
class NekoView(context: Context) : View(context) {
    private var bitmap: Bitmap? = null
    private val paint =
            Paint().apply {
                isAntiAlias = true
                isFilterBitmap = true
            }
    private var offsetX = 0f
    private var offsetY = 0f
    private val handler = Handler(Looper.getMainLooper())
    private var isAnimating = false
    private val TAG = "NekoView"
    private var frameCount = 0

    fun setBitmap(bitmap: Bitmap) {
        this.bitmap = bitmap
        Log.d(TAG, "Bitmap set: ${bitmap.width}x${bitmap.height}")
        // Start animation loop
        startAnimation()
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        bitmap?.let {
            // Draw with offset for animation
            canvas.drawBitmap(it, offsetX, offsetY, paint)
        }
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val width = bitmap?.width ?: 100
        val height = bitmap?.height ?: 100
        setMeasuredDimension(width, height)
    }

    private fun startAnimation() {
        if (isAnimating) return
        isAnimating = true
        Log.d(TAG, "Animation started")
        animateNeko()
    }

    private fun animateNeko() {
        if (!isAnimating) return

        frameCount++

        // Larger, more visible circular motion
        val time = System.currentTimeMillis() / 1000.0
        offsetX = (Math.sin(time * 2.0) * 20).toFloat()
        offsetY = (Math.cos(time * 2.0) * 20).toFloat()

        if (frameCount % 60 == 0) {
            Log.d(TAG, "Frame $frameCount - offsetX: $offsetX, offsetY: $offsetY")
        }

        invalidate()

        // Continue animation at ~60 FPS
        handler.postDelayed({ animateNeko() }, 16)
    }

    fun cleanup() {
        Log.d(TAG, "Cleanup called, total frames: $frameCount")
        isAnimating = false
        handler.removeCallbacksAndMessages(null)
        bitmap?.recycle()
        bitmap = null
    }
}
