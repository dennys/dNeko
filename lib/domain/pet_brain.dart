import 'dart:math';
import 'dart:ui';
import 'i_pet_brain.dart';
import 'pet_behavior.dart';
import 'pet_decision.dart';

/// 只負責：依飢餓狀態隨機決定寵物的下一個自主行為
class PetBrain implements IPetBrain {
  final Random _random;

  PetBrain([Random? random]) : _random = random ?? Random();

  @override
  PetDecision decideNext(Rect bounds, {bool isHungry = false}) {
    // 餓的時候不睡覺，且更傾向到處走動找東西
    if (isHungry) {
      return _random.nextDouble() < 0.7
          ? PetDecision(PetBehavior.wander, target: _randomPoint(bounds))
          : PetDecision(
              PetBehavior.idle,
              holdTime: Duration(seconds: 1 + _random.nextInt(2)),
            );
    }

    final roll = _random.nextDouble();

    if (roll < 0.45) {
      return PetDecision(PetBehavior.wander, target: _randomPoint(bounds));
    }
    if (roll < 0.75) {
      return PetDecision(
        PetBehavior.idle,
        holdTime: Duration(seconds: 2 + _random.nextInt(3)),
      );
    }
    return PetDecision(
      PetBehavior.sleep,
      holdTime: Duration(seconds: 4 + _random.nextInt(4)),
    );
  }

  Offset _randomPoint(Rect b) => Offset(
        b.left + _random.nextDouble() * b.width,
        b.top + _random.nextDouble() * b.height,
      );
}