package com.dneko.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.dneko/native"
    private val OVERLAY_PERMISSION_REQUEST_CODE = 1234
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getNativeMessage" -> {
                    val message = getNativeMessage()
                    result.success(message)
                }
                "showOverlay" -> {
                    showOverlay(result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun getNativeMessage(): String {
        return "Hello from Kotlin ${KotlinVersion.CURRENT}!"
    }

    private fun showOverlay(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!Settings.canDrawOverlays(this)) {
                pendingResult = result
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName")
                )
                startActivityForResult(intent, OVERLAY_PERMISSION_REQUEST_CODE)
                return
            }
        }
        
        // Permission granted, show overlay
        val overlayService = OverlayService(this)
        overlayService.showOverlay()
        result.success("Overlay shown")
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == OVERLAY_PERMISSION_REQUEST_CODE) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (Settings.canDrawOverlays(this)) {
                    val overlayService = OverlayService(this)
                    overlayService.showOverlay()
                    pendingResult?.success("Overlay shown")
                } else {
                    pendingResult?.error("PERMISSION_DENIED", "Overlay permission denied", null)
                }
            }
            pendingResult = null
        }
    }
}
