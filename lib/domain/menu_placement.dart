import 'dart:ui';

/// 選單視窗的左上角與「選單開在動物上方還是下方」
class MenuPlacement {
  final Offset topLeft;

  /// 生產代碼目前不讀它（選單是另一個視窗，上下只是擺位差異），但 `placeMenuWindow` 的測試
  /// 靠它鎖住「優先開下方、放不下才往上」—— 別當死欄位刪掉
  final bool above;

  const MenuPlacement(this.topLeft, {required this.above});
}

/// 選單是**另一個視窗**時的左上角（`feat/overlay-menu-own-window`：動物的視窗不再為選單改尺寸）。
///
/// 跟 [placeMenu] 的差別只在「選單裡沒有動物」：不需要把動物塊算進高度，
/// 選單與動物之間留 [gap] 的空隙；優先開在動物下方，下方放不下才往上長。
/// 整個選單夾在 [roam] 之內（選單不能跑到狀態列／導航列外面）。
MenuPlacement placeMenuWindow({
  required Offset petPos,
  required double petSize,
  required Rect roam,
  required Size menuSize,
  double gap = 8,
}) {
  final petCenterX = petPos.dx + petSize / 2;
  final belowY = petPos.dy + petSize + gap;
  final aboveY = petPos.dy - gap - menuSize.height;
  final fitsBelow = belowY + menuSize.height <= roam.bottom;
  final fitsAbove = aboveY >= roam.top;
  // 兩邊都放不下時才靠空間比較多的那一側（放不下的那側還是會被夾回界內）
  final above = !fitsBelow && (fitsAbove || petPos.dy - roam.top > roam.bottom - petPos.dy);

  final x = _clampStart(
      petCenterX - menuSize.width / 2, roam.left, roam.right, menuSize.width);
  final y = _clampStart(above ? aboveY : belowY, roam.top, roam.bottom, menuSize.height);

  return MenuPlacement(Offset(x, y), above: above);
}

/// 把「起點」夾進 [min, max] 之內，同時保證整個 [size] 不出界。
/// 放不下（size 比範圍還大）時退化成貼 [min] —— 至少靠邊那一端看得見，
/// 總比讓選單溢出螢幕另一邊好。
double _clampStart(double start, double min, double max, double size) =>
    size >= max - min ? min : start.clamp(min, max - size).toDouble();
