import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:dneko/domain/pet_behavior.dart';
import 'package:dneko/domain/pet_bond.dart';
import 'package:dneko/domain/pet_brain.dart';
import 'package:dneko/domain/pet_stats.dart';

void main() {
  const today = 2026;
  DateTime d(int day, [int hour = 9]) => DateTime(today, 11, day, hour);

  group('PetBond 計分', () {
    test('摸：一天只有前 3 次算分（防連點刷分）', () {
      var b = const PetBond();
      for (var i = 0; i < PetBond.petDailyCap; i++) {
        b = b.awardPet(d(1));
      }
      expect(b.value, PetBond.petDailyCap * PetBond.petAward);
      expect(b.petTally, PetBond.petDailyCap);

      // 第 4 次開始完全不漲 —— 沒有這個額度，連點 100 下就能把親密度刷滿
      final capped = b.awardPet(d(1)).awardPet(d(1));
      expect(capped.value, b.value);
      expect(capped.petTally, b.petTally);
    });

    test('跨天歸零：今天的額度用盡，明天照樣能計分', () {
      var b = const PetBond();
      for (var i = 0; i < PetBond.petDailyCap + 2; i++) {
        b = b.awardPet(d(1));
      }
      b = b.awardPet(d(2)); // 換一天
      expect(b.petTally, 1);
      expect(b.value, (PetBond.petDailyCap + 1) * PetBond.petAward);
      expect(b.day, '2026-11-02');
    });

    test('摸與餵的額度各自獨立', () {
      var b = const PetBond();
      for (var i = 0; i < 5; i++) {
        b = b.awardPet(d(1)).awardFeed(d(1));
      }
      expect(b.petTally, PetBond.petDailyCap);
      expect(b.feedTally, PetBond.feedDailyCap);
      expect(
        b.value,
        PetBond.petDailyCap * PetBond.petAward + PetBond.feedDailyCap * PetBond.feedAward,
      );
    });

    test('只漲不跌，且封在 100', () {
      var b = const PetBond();
      for (var day = 1; day <= 60; day++) {
        b = b.awardPet(d(day)).awardFeed(d(day));
      }
      expect(b.value, PetBond.maxBond);
      expect(b.awardPet(d(61)).value, PetBond.maxBond); // 已滿就不再動
    });

    test('encode/decode 守住今天的額度（重開 app 不能重置額度）', () {
      var b = const PetBond().awardPet(d(3)).awardFeed(d(3));
      final back = PetBond.decode(b.encode())!;
      expect(back.value, b.value);
      expect(back.day, b.day);
      expect(back.petTally, b.petTally);
      expect(back.feedTally, b.feedTally);
      // 讀回來之後繼續摸，仍然受同一天的額度約束
      var more = back;
      for (var i = 0; i < 5; i++) {
        more = more.awardPet(d(3));
      }
      expect(more.petTally, PetBond.petDailyCap);
    });

    test('沒存過／壞資料回 null（呼叫端決定預設，不在這裡猜）', () {
      expect(PetBond.decode(null), isNull);
      expect(PetBond.decode(''), isNull);
      expect(PetBond.decode('42.0'), isNull);
      expect(PetBond.decode('{"day":"2026-11-11"}'), isNull); // 少了 bond
      expect(PetBond.decode('[1,2]'), isNull);
      // 欄位缺失時給預設值，不整筆丟掉
      final partial = PetBond.decode('{"bond":30}')!;
      expect(partial.value, 30);
      expect(partial.petTally, 0);
      expect(partial.feedTally, 0);
    });
  });

  group('PetStats 親密度', () {
    test('額度用盡時回傳 false —— 不該空轉 notifyListeners', () {
      final stats = PetStats();
      final notified = <int>[];
      stats.addListener(() => notified.add(stats.bondValue.round()));

      for (var i = 0; i < PetBond.petDailyCap; i++) {
        expect(stats.awardPet(d(1)), isTrue);
      }
      expect(stats.awardPet(d(1)), isFalse);
      expect(notified.length, PetBond.petDailyCap);
      expect(stats.bondValue, PetBond.petDailyCap * PetBond.petAward);
    });

    test('注入 initialBond 就接得住存盤值；親密度與餓度互不干預', () {
      final stats = PetStats(initialHunger: 50, initialBond: PetBond.decode('{"bond":42}')!);
      expect(stats.bondValue, 42);
      stats.tick(const Duration(minutes: 30));
      stats.feed();
      expect(stats.bondValue, 42); // 餓度怎麼變都不該動到親密度（含不跌）
    });
  });

  group('PetBrain：親密度唯一的後果是主動撒嬌', () {
    const bounds = Rect.fromLTWH(0, 0, 100, 100);

    Map<PetBehavior, int> tally(double bond, {bool isHungry = false, int n = 20000}) {
      final brain = PetBrain(Random(7));
      final out = <PetBehavior, int>{};
      for (var i = 0; i < n; i++) {
        final b = brain.decideNext(bounds, isHungry: isHungry, bond: bond).behavior;
        out[b] = (out[b] ?? 0) + 1;
      }
      return out;
    }

    test('bond=0 時不會主動撒嬌（與加這欄位之前的行為相同）', () {
      expect(tally(0)[PetBehavior.affectionate] ?? 0, 0);
    });

    test('bond 滿值時約 20% 主動撒嬌，其餘行為按原比例縮', () {
      final c = tally(100);
      final total = c.values.fold<int>(0, (a, b) => a + b);
      double share(PetBehavior b) => (c[b] ?? 0) / total;
      expect(share(PetBehavior.affectionate), closeTo(0.20, 0.02));
      expect(share(PetBehavior.wander), closeTo(0.36, 0.02)); // 0.45 × 0.8
      expect(share(PetBehavior.idle), closeTo(0.24, 0.02)); // 0.30 × 0.8
      expect(share(PetBehavior.sleep), closeTo(0.20, 0.02)); // 0.25 × 0.8
    });

    test('餓的時候親密度無效：不睡也不撒嬌，先去吃東西', () {
      final c = tally(100, isHungry: true, n: 5000);
      expect(c[PetBehavior.sleep] ?? 0, 0);
      expect(c[PetBehavior.affectionate] ?? 0, 0);
    });

    test('亂傳（負值、超過 100）不會把機率搞壞', () {
      expect(tally(-5)[PetBehavior.affectionate] ?? 0, 0);
      final over = tally(1e9);
      final total = over.values.fold<int>(0, (a, b) => a + b);
      expect((over[PetBehavior.affectionate] ?? 0) / total, closeTo(0.20, 0.02));
    });
  });
}
