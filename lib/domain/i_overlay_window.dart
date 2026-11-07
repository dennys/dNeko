import 'dart:ui';

/// 控制 OS 懸浮視窗的位置與大小（包裝 flutter_overlay_window 細節）
abstract interface class IOverlayWindow {
  /// 移動視窗左上角到螢幕座標（邏輯像素）
  Future<void> moveTo(Offset position);

  /// 調整視窗大小（邏輯像素）。enableDrag 控制是否允許原生拖曳（選單狀態應關閉）
  Future<void> resize({required double width, required double height, bool enableDrag = true});

  /// 讀取目前視窗左上角座標（邏輯像素），供原生拖曳後同步寵物位置
  Future<Offset> currentPosition();

  /// 關閉 overlay
  Future<void> close();
}