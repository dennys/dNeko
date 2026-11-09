import 'dart:ui';

/// 選單視窗的左上角與「選單是否開在動物上方」
class MenuPlacement {
  final Offset topLeft;
  final bool above;

  const MenuPlacement(this.topLeft, {required this.above});
}

/// 開選單時的視窗位置。動物固定不動：下方夠就朝下長；不夠就往上長（動物貼視窗底）；
/// 寬度變大時水平置中回動物原本的位置。整個視窗都夾在 [roam] 之內。
///
/// [petPos] 是動物（寵物視窗）目前的左上角；[roam] 是視窗實際可到達的頂端範圍。
MenuPlacement placeMenu({
  required Offset petPos,
  required Rect roam,
  required double petSize,
  required double menuWidth,
  required double menuHeight,
}) {
  final extra = menuHeight - petSize;
  final maxTop = roam.bottom + petSize - menuHeight; // 選單不壓到導航列的最大 y
  final belowFits = petPos.dy <= maxTop;
  final aboveFits = petPos.dy - extra >= roam.top;
  final above = !belowFits && (aboveFits || petPos.dy - roam.top > roam.bottom - petPos.dy);

  final maxLeft = roam.right + petSize - menuWidth; // 同理，左右不出界
  var x = petPos.dx - (menuWidth - petSize) / 2;
  if (x < roam.left) x = roam.left;
  if (maxLeft >= roam.left && x > maxLeft) x = maxLeft;

  var y = above ? petPos.dy - extra : petPos.dy;
  if (y < roam.top) y = roam.top;
  if (maxTop >= roam.top && y > maxTop) y = maxTop;

  return MenuPlacement(Offset(x, y), above: above);
}
