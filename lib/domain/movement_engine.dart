import 'dart:ui';
import 'i_movement_engine.dart';

/// 只負責：依速度往目標移動，並把座標限制在範圍內
class MovementEngine implements IMovementEngine {
  final double speedPerTick; // 每次 tick 移動的像素

  const MovementEngine({this.speedPerTick = 1.5});

  @override
  MovementResult step({
    required Offset current,
    required Offset target,
    required Rect bounds,
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