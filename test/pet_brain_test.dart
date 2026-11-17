import 'dart:math';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:dneko/domain/pet_behavior.dart';
import 'package:dneko/domain/pet_brain.dart';

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

    group('餓昏（滑稽鬧騰）', () {
      const drama = {PetBehavior.beg, PetBehavior.faint, PetBehavior.wobble};

      test('餓昏時絕不睡覺、絕不撒嬌', () {
        final brain = PetBrain(Random(7));
        for (var i = 0; i < 200; i++) {
          final b = brain.decideNext(bounds, isHungry: true, isStarving: true).behavior;
          expect(b, isNot(PetBehavior.sleep));
          expect(b, isNot(PetBehavior.affectionate));
        }
      });

      test('大部分時間在鬧，而且 beg/faint 都抽得到', () {
        final brain = PetBrain(Random(7));
        final counts = <PetBehavior, int>{};
        for (var i = 0; i < 300; i++) {
          final b = brain.decideNext(bounds, isHungry: true, isStarving: true).behavior;
          expect(
            {...drama, PetBehavior.wander, PetBehavior.idle},
            contains(b),
            reason: '餓昏只該在鬧騰／找吃的／喘口氣之間輪',
          );
          counts[b] = (counts[b] ?? 0) + 1;
        }
        final dramaCount = drama.fold(0, (sum, b) => sum + (counts[b] ?? 0));
        expect(dramaCount, greaterThan(180), reason: '不到六成就看不出牠餓昏');
        expect(counts[PetBehavior.beg], greaterThan(0), reason: '討食是主戲，不能抽不到');
        expect(counts[PetBehavior.faint], greaterThan(0), reason: '裝死是笑點，不能抽不到');
      });

      test('餓昏的 wander 目標仍在界內', () {
        final brain = PetBrain(Random(11));
        for (var i = 0; i < 100; i++) {
          final d = brain.decideNext(bounds, isHungry: true, isStarving: true);
          if (d.behavior == PetBehavior.wander) expect(bounds.contains(d.target!), isTrue);
        }
      });

      test('只有「餓」沒「餓昏」時決定不變（不會突然開始裝死）', () {
        final brain = PetBrain(Random(3));
        for (var i = 0; i < 100; i++) {
          final b = brain.decideNext(bounds, isHungry: true).behavior;
          expect(b, isNot(PetBehavior.beg));
          expect(b, isNot(PetBehavior.faint));
        }
      });

      test('不餓也不餓昏時一樣不會鬧（餓昏是唯一開關）', () {
        final brain = PetBrain(Random(5));
        for (var i = 0; i < 100; i++) {
          final b = brain.decideNext(bounds).behavior;
          expect(b, isNot(PetBehavior.beg));
          expect(b, isNot(PetBehavior.faint));
        }
      });
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
