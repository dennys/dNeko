import 'dart:ui';

import '../../domain/menu_placement.dart';

/// 選單開著時，Windows 那顆（唯一）視窗要蓋住「寵物 + 選單」的範圍。
///
/// 為什麼要抽成純函式並單獨測：這是整個 Windows 版最容易錯的地方 —— 算錯 1px 就會看到
/// 寵物在開選單瞬間跳位（Android 上那個 `FlutterTextureView` 拉伸 bug 就是同類問題，
/// 只是那邊沒有測試）。几何算對了，剩下的都只是把三個 Rectangle 交給 window_manager。
class WindowLayout {
  /// 視窗新的左上角與尺寸（邏輯像素）
  final Rect window;

  /// 寵物要畫在視窗內的哪個點
  final Offset petAt;

  /// 選單要畫在視窗內的哪個點
  final Offset menuAt;

  const WindowLayout({required this.window, required this.petAt, required this.menuAt});
}

/// [petPos] 是寵物視窗目前的左上角（= 寵物位置），[screen] 是牠能待的範圍。
/// 選單優先開在寵物下方，放不下才往上（沿用 [placeMenuWindow] 的規則，兩側行為一致）。
WindowLayout layoutWithMenu({
  required Offset petPos,
  required double petSize,
  required Size menuSize,
  required Rect screen,
  double gap = 8,
}) {
  final petRect = Rect.fromLTWH(petPos.dx, petPos.dy, petSize, petSize);
  final placement = placeMenuWindow(
    petPos: petPos,
    petSize: petSize,
    roam: screen,
    menuSize: menuSize,
    gap: gap,
  );
  final menuRect = Rect.fromLTWH(placement.topLeft.dx, placement.topLeft.dy, menuSize.width, menuSize.height);
  final union = petRect.expandToInclude(menuRect);
  return WindowLayout(
    window: union,
    petAt: Offset(petRect.left - union.left, petRect.top - union.top),
    menuAt: Offset(menuRect.left - union.left, menuRect.top - union.top),
  );
}
