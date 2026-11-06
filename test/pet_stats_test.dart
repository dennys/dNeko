import 'package:flutter_test/flutter_test.dart';
import 'package:dneko/domain/pet_stats.dart';

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
      final stats = PetStats(initialHunger: 0, hungerPerSecond: 1);
      stats.feed(amount: 50);
      expect(stats.hunger, 0);

      stats.tick(const Duration(seconds: 1000));
      expect(stats.hunger, PetStats.maxHunger);
    });

    // 舊的預設值是每秒 1 點：開機 100 秒就永遠滿飢餓，而餵食只贖回 40 點，
    // 之後 isHungry 恆為 true → PetBrain 永遠只選 wander/idle，再也沒睡過覺。
    test('預設速度下不會幾分鐘就餓死', () {
      final stats = PetStats();
      stats.tick(const Duration(seconds: 100));
      expect(stats.hunger, lessThan(PetStats.maxHunger / 3), reason: '100 秒只該漲約 1.7 點');
      expect(stats.isHungry, isFalse);

      // 飽足的宠物要過約一小時才會餓
      stats.tick(const Duration(minutes: 61));
      expect(stats.isHungry, isTrue);
    });

    test('餵一次food 撐過餓的門檻', () {
      final stats = PetStats(initialHunger: PetStats.defaultHungryThreshold - 1);
      stats.feed();
      expect(stats.isHungry, isFalse);
    });

    group('通知節流', () {
      test('16ms 一跳的空轉不會每跳都通知', () {
        final stats = PetStats();
        var notifications = 0;
        stats.addListener(() => notifications++);

        // 模擬 60fps 跑 10 分鐘：漲約 10 點，但不該通知 36000 次
        for (var i = 0; i < 60 * 600; i++) {
          stats.tick(const Duration(milliseconds: 16));
        }

        expect(stats.hunger, greaterThan(5));
        expect(notifications, inInclusiveRange(1, 20), reason: '只該在跨過 1 點解析度時通知');
      });

      test('跨過飢餓門檻那一刻一定会通知', () {
        final stats = PetStats(hungerPerSecond: 1);
        var notifications = 0;
        stats.addListener(() => notifications++);

        stats.tick(const Duration(seconds: 59));
        expect(stats.isHungry, isFalse);
        final before = notifications;

        // 跨過門檻這一刻就算變化量不到 1 點也要通知（HungerBar 的顏色、PetBrain 的決策都看它）
        stats.tick(const Duration(milliseconds: 1600));
        expect(stats.isHungry, isTrue);
        expect(notifications, greaterThan(before));
      });

      test('已經餓透之後繼續 tick 不會每幀都通知', () {
        // early-return 被拿掉過的版本：hunger 恆為 maxHunger 時每幀都算出「在邊界上」，
        // 於是 60 次/秒通知 UI —— 桌寵最糟的一種空轉。
        final stats = PetStats(hungerPerSecond: 1);
        stats.tick(const Duration(seconds: 200));
        expect(stats.hunger, PetStats.maxHunger);

        var notifications = 0;
        stats.addListener(() => notifications++);
        for (var i = 0; i < 600; i++) {
          stats.tick(const Duration(milliseconds: 16));
        }
        expect(notifications, 0);
      });

      test('到 0 與到上限這種邊界一定会通知', () {
        final stats = PetStats(initialHunger: 0.4, hungerPerSecond: 1);
        var notifications = 0;
        stats.addListener(() => notifications++);

        stats.feed(amount: 0.4);
        expect(stats.hunger, 0);
        expect(notifications, 1);
      });
    });
  });
}
