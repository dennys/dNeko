import 'dart:ui';

/// 只負責：依速度往目標移動，並把座標限制在範圍內
class MovementEngine {
  final double speedPerTick; // 每次 tick 移動的像素
  const MovementEngine({this.speedPerTick = 1.5});

  /// 回傳新座標；arrived 表示是否已抵達目標
  ({Offset position, bool arrived}) step({
    required Offset current,
    required Offset target,
    required Rect bounds, // 可活動範圍（限定區域）
  }) {
    final delta = target - current;
    if (delta.distance <= speedPerTick) {
      return (position: _clamp(target, bounds), arrived: true);
    }
    final direction = delta / delta.distance;
    final next = current + direction * speedPerTick;
    return (position: _clamp(next, bounds), arrived: false);
  }

  Offset _clamp(Offset p, Rect b) => Offset(
        p.dx.clamp(b.left, b.right),
        p.dy.clamp(b.top, b.bottom),
      );
}