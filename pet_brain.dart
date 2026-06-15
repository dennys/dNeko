import 'dart:math';
import 'dart:ui';
import 'pet_behavior.dart';

class PetDecision {
  final PetBehavior behavior;
  final Offset? target;      // wander/goToFood 才有
  final Duration holdTime;   // idle/sleep/eating 停留時間
  const PetDecision(this.behavior, {this.target, this.holdTime = Duration.zero});
}

/// 只負責：隨機決定寵物的下一個自主行為
class PetBrain {
  final Random _random;
  PetBrain([Random? random]) : _random = random ?? Random();

  PetDecision decideNext(Rect bounds) {
    final roll = _random.nextDouble();

    if (roll < 0.45) {
      return PetDecision(PetBehavior.wander, target: _randomPoint(bounds));
    }
    if (roll < 0.75) {
      return PetDecision(PetBehavior.idle,
          holdTime: Duration(seconds: 2 + _random.nextInt(3)));
    }
    return PetDecision(PetBehavior.sleep,
        holdTime: Duration(seconds: 4 + _random.nextInt(4)));
  }

  Offset _randomPoint(Rect b) => Offset(
        b.left + _random.nextDouble() * b.width,
        b.top + _random.nextDouble() * b.height,
      );
}