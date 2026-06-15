import 'dart:math';
import 'dart:ui';

/// 寵物碰到螢幕邊緣時要採取的下一個目標
abstract interface class IEdgeBehavior {
  /// 回傳是否正貼著邊緣
  bool isAtEdge(Offset position, Rect bounds, {double tolerance = 1.0});

  /// 依目前位置算出「碰邊後」的新目標點
  Offset nextTargetOnEdge(Offset position, Rect bounds);
}

/// 沿邊走策略：碰到邊緣後沿著該邊往隨機方向移動
class EdgeWalkBehavior implements IEdgeBehavior {
  final Random _random;

  EdgeWalkBehavior([Random? random]) : _random = random ?? Random();

  @override
  bool isAtEdge(Offset position, Rect bounds, {double tolerance = 1.0}) {
    final atLeft = (position.dx - bounds.left).abs() <= tolerance;
    final atRight = (position.dx - bounds.right).abs() <= tolerance;
    final atTop = (position.dy - bounds.top).abs() <= tolerance;
    final atBottom = (position.dy - bounds.bottom).abs() <= tolerance;
    return atLeft || atRight || atTop || atBottom;
  }

  @override
  Offset nextTargetOnEdge(Offset position, Rect bounds) {
    final atLeft = (position.dx - bounds.left).abs() <= 1.0;
    final atRight = (position.dx - bounds.right).abs() <= 1.0;
    final atTop = (position.dy - bounds.top).abs() <= 1.0;

    // 在左右邊 → 沿垂直方向走；在上下邊 → 沿水平方向走
    if (atLeft || atRight) {
      final targetY = bounds.top +
          _random.nextDouble() * (bounds.bottom - bounds.top);
      return Offset(position.dx, targetY);
    }
    if (atTop) {
      final targetX = bounds.left +
          _random.nextDouble() * (bounds.right - bounds.left);
      return Offset(targetX, bounds.top);
    }
    // 底邊
    final targetX =
        bounds.left + _random.nextDouble() * (bounds.right - bounds.left);
    return Offset(targetX, bounds.bottom);
  }
}

/// 回頭策略：碰到邊緣後往螢幕中央走
class EdgeTurnBackBehavior implements IEdgeBehavior {
  @override
  bool isAtEdge(Offset position, Rect bounds, {double tolerance = 1.0}) {
    final atLeft = (position.dx - bounds.left).abs() <= tolerance;
    final atRight = (position.dx - bounds.right).abs() <= tolerance;
    final atTop = (position.dy - bounds.top).abs() <= tolerance;
    final atBottom = (position.dy - bounds.bottom).abs() <= tolerance;
    return atLeft || atRight || atTop || atBottom;
  }

  @override
  Offset nextTargetOnEdge(Offset position, Rect bounds) => bounds.center;
}