import 'package:flutter_test/flutter_test.dart';
import 'package:dneko/domain/pet_stats.dart';

void main() {
  group('PetStats', () {
    test('隨時間累積飢餓值', () {
      final stats = PetStats(hungerPerSecond: 10);
      stats.tick(const Duration(seconds: 2));
      expect(stats.hunger, closeTo(20, 0.0001));
    });

    // ②B：判準是 `>` 不是 `>=`，而且 PetStats 與 HungerBar 共用 PetStats.isHungryAt 這一份。
    test('超過門檻才算餓，剛好等於門檻不算餓', () {
      expect(PetStats(initialHunger: 61, hungryThreshold: 60).isHungry, isTrue);
      expect(PetStats(initialHunger: 60, hungryThreshold: 60).isHungry, isFalse);
      expect(PetStats.isHungryAt(60, 60), isFalse);
      expect(PetStats.isHungryAt(60.01, 60), isTrue);
    });

    test('餓透餵一次就要能脫餓（>= 的年代要餵兩次，看起來像餵了沒反應）', () {
      final stats = PetStats(initialHunger: PetStats.maxHunger); // 餓透 100
      expect(stats.isHungry, isTrue);

      stats.feed(); // 餵食量 40 → 60，剛好落在預設門檻上
      expect(stats.hunger, 60);
      expect(stats.isHungry, isFalse,
          reason: '60 >= 60 的年代這裡仍判餓 → PetBrain 絕不睡覺 → 必須再餵一次');
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

    group('餓的門檻（分鐘設定）', () {
      test('hungryThresholdForMinutes：預設速率下分鐘數＝點數', () {
        expect(PetStats.hungryThresholdForMinutes(60), 60);
        expect(PetStats.hungryThresholdForMinutes(1), 1);
        expect(PetStats.hungryThresholdForMinutes(100), PetStats.maxHunger);
      });

      test('hungryThresholdForMinutes：自訂速率照換算', () {
        // 10 分鐘 × 60 秒 × 2 點/秒 = 1200 點（超過 maxHunger，代表永遠餓不到）
        expect(PetStats.hungryThresholdForMinutes(10, perSecond: 2), 1200);
      });

      test('setHungryThreshold 翻轉 isHungry 才通知', () {
        final stats = PetStats(initialHunger: 50);
        var notifications = 0;
        stats.addListener(() => notifications++);

        // 50 → 門檻降到 40：isHungry false→true，要通知
        stats.setHungryThreshold(40);
        expect(stats.isHungry, isTrue);
        expect(notifications, 1);

        // 門檻升到 80：isHungry true→false，要通知
        stats.setHungryThreshold(80);
        expect(stats.isHungry, isFalse);
        expect(notifications, 2);

        // 門檻 80→90：isHungry 仍是 false，不通知
        stats.setHungryThreshold(90);
        expect(notifications, 2);

        // 同一值：不通知
        stats.setHungryThreshold(90);
        expect(notifications, 2);
      });

      test('餵食跨過新門檻也會通知（門檻改完後 tick 路徑不受影響）', () {
        final stats = PetStats(initialHunger: 70, hungryThreshold: 80);
        var notifications = 0;
        stats.addListener(() => notifications++);

        stats.feed(amount: 15); // 70 → 55，跨過門檻 80 往下
        expect(stats.isHungry, isFalse);
        expect(notifications, 1);
      });
    });
  });
}
