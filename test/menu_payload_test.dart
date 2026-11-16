import 'package:flutter_test/flutter_test.dart';

import 'package:dneko/domain/menu_payload.dart';
import 'package:dneko/domain/pet_behavior.dart';
import 'package:dneko/domain/pet_stats.dart';

void main() {
  MenuPayload sample() => MenuPayload(
        themeMode: 'dark',
        languageCode: 'zh',
        hunger: 37.5,
        hungryThreshold: 60,
        bondValue: 23,
        frozen: true,
        labels: {'feed': '餵食', PetBehavior.hop.name: '跳跳'},
      );

  group('MenuPayload', () {
    test('encode → decode 之後欄位不跑掉（選單那一側讀的就是這份）', () {
      final back = MenuPayload.decode(sample().encode());
      expect(back, isNotNull);
      expect(back!.themeMode, 'dark');
      expect(back.languageCode, 'zh');
      expect(back.hunger, 37.5);
      expect(back.hungryThreshold, 60);
      expect(back.bondValue, 23);
      expect(back.frozen, isTrue);
      expect(back.labelFor('feed'), '餵食');
    });

    test('JSON 把 20.0 寫成 int 也不會炸（跨 isolate 的數字 int/double 會互相竄）', () {
      final back = MenuPayload.decode('{"hunger":20,"bondValue":3.0}');
      expect(back, isNotNull);
      expect(back!.hunger, 20);
      expect(back.bondValue, 3);
    });

    test('讀不到就用安全預設：門檻跟 PetStats 同一個來源，選單不會自己編一個', () {
      final back = MenuPayload.decode('{}')!;
      expect(back.hunger, 0);
      expect(back.frozen, isFalse);
      expect(back.hungryThreshold, PetStats.defaultHungryThreshold);
    });

    test('壞掉的 JSON / null 回 null，讓選單畫面留空而不是崩', () {
      expect(MenuPayload.decode(null), isNull);
      expect(MenuPayload.decode(''), isNull);
      expect(MenuPayload.decode('{不是 JSON'), isNull);
      expect(MenuPayload.decode('[1,2]'), isNull);
    });

    test('沒翻好的 key 就顯示 key 本身（至少看得見按的是哪一格）', () {
      expect(sample().labelFor('nope'), 'nope');
    });
  });

  group('kFlourishBehaviors', () {
    test('正好六格 —— FeedingMenu 的網格是 3×2，多一格少一格都開不出選單', () {
      expect(kFlourishBehaviors.length, 6);
      expect(kFlourishBehaviors.toSet().length, 6, reason: '不能重複');
    });

    test('名稱可直接還原成 PetBehavior（寵物那側靠名字收指令）', () {
      for (final behavior in kFlourishBehaviors) {
        expect(PetBehavior.values.byName(behavior.name), behavior);
      }
    });
  });
}
