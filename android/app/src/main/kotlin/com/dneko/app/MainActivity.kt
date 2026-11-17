package com.dneko.app

import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// 懸浮視窗全部走 flutter_overlay_window（見 lib/data/services/overlay_window.dart），
// 懸浮權限也是 —— 主頁 _toggle 呼叫的 hasPermission/requestPermission 就是該插件的
// OverlayWindow.hasPermission/requestPermission（本專案沒有 permission_handler 這個依賴）。
// 這裡的 com.dneko/app 通道只做兩件事：把桌面捷徑帶進來的 pending action 交給 Dart、
// 以及 requestPinShortcut（要釘哪個捷徑、按下要做什麼，邏輯都留在 Dart/Manifest 兩端）。
class MainActivity : FlutterActivity() {

    private var pendingAction: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        pendingAction = intent?.getStringExtra(EXTRA_ACTION)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // singleTop：捷徑二次拉起走這，更新標記
        pendingAction = intent.getStringExtra(EXTRA_ACTION)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "takePendingAction" -> {
                        val action = pendingAction
                        pendingAction = null // 只發一次，避免 rotation/resume 重複觸發
                        result.success(action)
                    }

                    "pinToggleShortcut" -> result.success(pinToggleShortcut())
                    // 選單的第二個視窗（見 MenuOverlay.kt）：開懸浮時就把選單那顆 engine 预热好，
                    // 第一次長按才不用等冷啟動；關懸浮時兼做兜底，把還開著的選單一起收掉。
                    "preWarmMenu" -> {
                        MenuOverlay.preWarm(applicationContext)
                        result.success(true)
                    }
                    "hideMenu" -> {
                        MenuOverlay.hideMenu()
                        result.success(true)
                    }
                    "disposeMenu" -> {
                        MenuOverlay.disposeMenu()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun pinToggleShortcut(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val manager = getSystemService(ShortcutManager::class.java) ?: return false
        if (!manager.isRequestPinShortcutSupported) return false
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("dneko://toggle"))
            .setClass(this, ToggleShortcutActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val shortcut = ShortcutInfo.Builder(this, TOGGLE_SHORTCUT_ID)
            .setShortLabel("dNeko")
            .setIcon(Icon.createWithResource(this, R.mipmap.launcher_icon))
            .setIntent(intent)
            .build()
        return manager.requestPinShortcut(shortcut, null)
    }

    companion object {
        const val CHANNEL = "com.dneko/app"
        const val EXTRA_ACTION = "pending_action"
        private const val TOGGLE_SHORTCUT_ID = "dneko-toggle"
    }
}
