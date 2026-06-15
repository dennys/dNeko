import 'dart:math';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_pet/domain/pet_behavior.dart';
import 'package:desktop_pet/domain/pet_brain.dart';

void main() {
  const bounds = Rect.fromLTWH(0, 0, 100, 100);

  group('PetBrain', () {
    test('飢餓時不會決定睡覺', () {
      // 固定 seed 確保可重現
      final brain = PetBrain(Random(1));
      for (var i = 0; i < 100; i++) {
        final decision = brain.decideNext(bounds, isHungry: true);
        expect(decision.behavior, isNot(PetBehavior.sleep));
      }
    });

    test('wander 決策會帶有界內目標座標', () {
      final brain = PetBrain(Random(42));
      for (var i = 0; i < 100; i++) {
        final decision = brain.decideNext(bounds);
        if (decision.behavior == PetBehavior.wander) {
          expect(bounds.contains(decision.target!), isTrue);
        }
      }
    });
  });
}