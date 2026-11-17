import 'dart:ui';

/// 控制 OS 懸浮視窗的位置與大小（包裝 flutter_overlay_window 細節）
abstract interface class IOverlayWindow {
  /// 移動視窗左上角到螢幕座標（邏輯像素）。
  ///
  /// 回傳平台**有没有真的接受這次搬動**。`false` = 視窗已經不在（插件在 service 被關掉後
  /// 只是 `result.success(false)`，不擲例外），所以呼叫端要用它來發覺「懸浮其實已經關了」。
  /// 之前這裡是 `Future<void>`，那個 false 被丟掉 → driver 以為每次都成功了。
  Future<bool> moveTo(Offset position);

  /// 調整視窗大小（邏輯像素），同樣回傳平台有没有接受。
  /// 只有寵物尺寸變更才會用到 —— 選單是另一個視窗，
  /// 不再靠改這個視窗的大小來顯示（見 menu_main.dart 與原生 MenuOverlay.kt）
  Future<bool> resize({required double width, required double height});

  /// 讀取目前視窗左上角座標（邏輯像素），供原生拖曳後同步寵物位置
  Future<Offset> currentPosition();

  /// 關閉 overlay
  Future<void> close();
}