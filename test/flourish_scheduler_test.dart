import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:dneko/domain/flourish_scheduler.dart';
import 'package:dneko/domain/pet_behavior.dart';

void main() {
  group('FlourishScheduler', () {
    test('沒有候選時回傳 null', () {
      final s = FlourishScheduler(random: Random(1), chancePerMinute: 1.0);
      expect(s.tryPick(const Duration(minutes: 1), const []), isNull);
    });

    test('機率為 0 時永遠不觸發', () {
      final s = FlourishScheduler(random: Random(1), chancePerMinute: 0);
      for (var i = 0; i < 100; i++) {
        expect(s.tryPick(const Duration(minutes: 1), [PetBehavior.doze]), isNull);
      }
    });

    test('機率為 1 時一分鐘內必定觸發，並從候選中挑選', () {
      final s = FlourishScheduler(random: Random(1), chancePerMinute: 1.0);
      expect(s.tryPick(const Duration(minutes: 1), [PetBehavior.hop]), PetBehavior.hop);
    });

    test('觸發後進入冷卻，冷卻期間不會再觸發', () {
      final s = FlourishScheduler(random: Random(1), chancePerMinute: 1.0);
      s.tryPick(const Duration(minutes: 1), [PetBehavior.hop]);

      expect(s.tryPick(const Duration(seconds: 10), [PetBehavior.hop]), isNull);
      expect(s.tryPick(const Duration(seconds: 10), [PetBehavior.hop]), isNull);
    });

    test('冷卻結束後可以再次觸發', () {
      final s = FlourishScheduler(random: Random(1), chancePerMinute: 1.0);
      s.tryPick(const Duration(minutes: 1), [PetBehavior.hop]);

      // 冷卻 30 秒：先耗掉 25 秒，剩 5 秒；再推進一分鐘必定能抽
      s.tryPick(const Duration(seconds: 25), [PetBehavior.hop]);
      expect(s.tryPick(const Duration(minutes: 1), [PetBehavior.doze]), PetBehavior.doze);
    });

    test('候選為空時不進入冷卻，之後有候選就能立刻觸發', () {
      final s = FlourishScheduler(random: Random(1), chancePerMinute: 1.0);
      expect(s.tryPick(const Duration(minutes: 1), const []), isNull);
      expect(s.tryPick(const Duration(minutes: 1), [PetBehavior.stretch]), PetBehavior.stretch);
    });
  });
}
