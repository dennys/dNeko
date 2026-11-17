package com.dneko.app

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import flutter.overlay.window.flutter_overlay_window.OverlayService

/// 桌面捷徑的落點：沒有 UI、立刻 finish。
///
/// 寵物在跑 → 直接 stopService（和插件 closeOverlay 同一個動作），App 完全不會開。
/// 正因為 App 不會開，Dart 那側的 `OverlayService.close()`（唯一會呼叫 hideMenu /
/// disposeMenu 的地方）也不會跑 —— 所以**選單那顆視窗與第二顆 FlutterEngine 要在這裡自己收**，
/// 否則關掉寵物之後那顆 engine 會一直住在進程裡（選單開著時還會留一張關不掉的視窗）。
/// 沒在跑 → 帶 toggle 標記拉 MainActivity，啟動流程（權限請求、showOverlay、
/// metrics/語系）全留在 Dart 端——在原生重寫一套這種事遲早腐掉。
class ToggleShortcutActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (OverlayService.isRunning) {
            MenuOverlay.hideMenu()
            MenuOverlay.disposeMenu()
            stopService(Intent(this, OverlayService::class.java))
        } else {
            startActivity(
                Intent(this, MainActivity::class.java)
                    .putExtra(MainActivity.EXTRA_ACTION, "toggle")
                    .addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP
                    )
            )
        }
        finish()
    }
}
