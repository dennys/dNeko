import 'dart:ui';

/// 控制 OS 懸浮視窗的位置與大小（包裝 flutter_overlay_window 細節）
abstract interface class IOverlayWindow {
  /// 移動視窗左上角到螢幕座標（邏輯像素）
  Future<void> moveTo(Offset position);

  /// 調整視窗大小（邏輯像素）；原生拖曳保持開著（要連 enableDrag 一起改請用實作的
  /// moveAndResize，介面不暴露那個參數 —— 它從來就不是呼叫端決定的）
  Future<void> resize({required double width, required double height});

  /// 讀取目前視窗左上角座標（邏輯像素），供原生拖曳後同步寵物位置
  Future<Offset> currentPosition();

  /// 關閉 overlay
  Future<void> close();
}