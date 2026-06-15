import 'dart:ui';
import '../data/models/animation_action.dart';

/// 只負責：把移動向量轉成對應的 8 方向走路動作
class DirectionResolver {
  const DirectionResolver();

  AnimationAction fromVelocity(Offset velocity) {
    if (velocity.distance == 0) return AnimationAction.walkDown;

    const deadZone = 0.4; // 對角線判定門檻
    final nx = velocity.dx / velocity.distance;
    final ny = velocity.dy / velocity.distance; // 螢幕座標：向下為正

    final left = nx < -deadZone;
    final right = nx > deadZone;
    final up = ny < -deadZone;
    final down = ny > deadZone;

    if (up && left) return AnimationAction.walkUpLeft;
    if (up && right) return AnimationAction.walkUpRight;
    if (down && left) return AnimationAction.walkDownLeft;
    if (down && right) return AnimationAction.walkDownRight;
    if (up) return AnimationAction.walkUp;
    if (down) return AnimationAction.walkDown;
    if (left) return AnimationAction.walkLeft;
    return AnimationAction.walkRight;
  }
}