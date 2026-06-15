import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_pet/domain/pet_stats.dart';

void main() {
  group('PetStats', () {
    test('隨時間累積飢餓值', () {
      final stats = PetStats(hungerPerSecond: 10);
      stats.tick(const Duration(seconds: 2));
      expect(stats.hunger, closeTo(20, 0.0001));
    });

    test('超過門檻時 isHungry 為 true', () {
      final stats = PetStats(initialHunger: 60, hungryThreshold: 60);
      expect(stats.isHungry, isTrue);
    });

    test('進食後降低飢餓值', () {
      final stats = PetStats(initialHunger: 50);
      stats.feed(amount: 40);
      expect(stats.hunger, closeTo(10, 0.0001));
    });

    test('飢餓值不超過上限也不低於 0', () {
      final stats = PetStats(initialHunger: 0);
      stats.feed(amount: 50);
      expect(stats.hunger, 0);

      stats.tick(const Duration(seconds: 1000));
      expect(stats.hunger, PetStats.maxHunger);
    });
  });
}