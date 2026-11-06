package com.dneko.app

import io.flutter.embedding.android.FlutterActivity

// 懸浮視窗全部走 flutter_overlay_window（見 lib/data/services/overlay_window.dart），
// 權限則由 permission_handler 處理（lib/main.dart 的 _toggle）。
// 這裡原本還有一個 "com.dneko/native" 的 MethodChannel + OverlayService/NekoView（約 250 行）：
// 它沒在 AndroidManifest 註冊、Dart 端沒有任何呼叫、讀的 assets/dneko.png 也沒進 asset bundle，
// 所以是永遠不會被執行到的範例殘留，已刪除。
class MainActivity : FlutterActivity()
