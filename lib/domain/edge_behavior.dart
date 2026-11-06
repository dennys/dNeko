import 'dart:math';
import 'dart:ui';

/// 貼邊判定的容差（像素）
const double edgeTolerance = 1.0;

/// 寵物碰到螢幕邊緣時要採取的下一個目標
abstract interface class IEdgeBehavior {
  /// 回傳是否正貼著邊緣
  bool isAtEdge(Offset position, Rect bounds, {double tolerance});

  /// 依目前位置算出「碰邊後」的新目標點
  Offset nextTargetOnEdge(Offset position, Rect bounds, {double tolerance});
}

/// 兩個策略共用的貼邊判定（以前在兩個類別裡逐字複製過一遍）。
bool isAtEdgeOf(Offset position, Rect bounds, {double tolerance = edgeTolerance}) =>
    _near(position.dx, bounds.left, tolerance) ||
    _near(position.dx, bounds.right, tolerance) ||
    _near(position.dy, bounds.top, tolerance) ||
    _near(position.dy, bounds.bottom, tolerance);

bool _near(double value, double edge, double tolerance) => (value - edge).abs() <= tolerance;

/// 沿邊走策略：碰到邊緣後沿著該邊往隨機方向移動
class EdgeWalkBehavior implements IEdgeBehavior {
  final Random _random;

  EdgeWalkBehavior([Random? random]) : _random = random ?? Random();

  @override
  bool isAtEdge(Offset position, Rect bounds, {double tolerance = edgeTolerance}) =>
      isAtEdgeOf(position, bounds, tolerance: tolerance);

  @override
  Offset nextTargetOnEdge(Offset position, Rect bounds, {double tolerance = edgeTolerance}) {
    // 在左右邊 → 沿垂直方向走；否則（上/下邊）沿水平方向走
    if (_near(position.dx, bounds.left, tolerance) || _near(position.dx, bounds.right, tolerance)) {
      return Offset(position.dx, bounds.top + _random.nextDouble() * bounds.height);
    }
    final atTop = _near(position.dy, bounds.top, tolerance);
    return Offset(bounds.left + _random.nextDouble() * bounds.width, atTop ? bounds.top : bounds.bottom);
  }
}

/// 回頭策略：碰到邊緣後往螢幕中央走
class EdgeTurnBackBehavior implements IEdgeBehavior {
  @override
  bool isAtEdge(Offset position, Rect bounds, {double tolerance = edgeTolerance}) =>
      isAtEdgeOf(position, bounds, tolerance: tolerance);

  @override
  Offset nextTargetOnEdge(Offset position, Rect bounds, {double tolerance = edgeTolerance}) => bounds.center;
}
