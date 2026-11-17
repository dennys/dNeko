import 'package:flutter_test/flutter_test.dart';
import 'package:dneko/data/repositories/settings_repository.dart';
import 'package:dneko/domain/pet_stats.dart';

/// 各養各的（per-animal 狀態）的契約測試。
///
/// 這一檔**不碰 DB**（真開 sqflite 在本機沒有 ffi 後端），測的是三個真正會被改壞的東西：
/// 1. on-disk 的鍵名 —— 改了等於使用者資料搬家，要有測試擋著；
/// 2. 「收起來的寵物不餓」這條規則（[hungerOnWake]，人類的決定）；
/// 3. 餓度編解碼含 `shown` 旗標，以及舊資料（沒有旗標 / 裸小數）讀得進來。
void main() {
  group('鍵名是 on-disk 格式', () {
    test('每隻各一把，且不等於 v1 的全域鍵', () {
      expect(SettingsRepository.hungerKey('cat'), 'pet_hunger_cat');
      expect(SettingsRepository.positionKey('cat'), 'pet_position_cat');
      expect(SettingsRepository.bondKey('cat'), 'pet_bond_cat');
      expect(SettingsRepository.hungerKey('cat'), isNot('pet_hunger'));
      expect(SettingsRepository.positionKey('cat'), isNot('pet_position'));
      expect(SettingsRepository.hungerKey('cat'), isNot(SettingsRepository.hungerKey('dog')));
    });
  });

  group('收起來的寵物不餓（hungerOnWake）', () {
    final now = DateTime(2026, 11, 17, 12);

    test('沒資料 = 沒養過這隻 → 飽的出場', () {
      expect(hungerOnWake(null, now), 0);
    });

    test('正常收起來（wasDisplayed=false）→ 三天後回來還是那個餓度', () {
      final saved = (hunger: 30.0, savedAt: now.subtract(const Duration(days: 3)), wasDisplayed: false);
      expect(hungerOnWake(saved, now), 30);
    });

    test('當掉／被系統殺（wasDisplayed=true）→ 依缺席時間補算', () {
      final saved = (hunger: 0.0, savedAt: now.subtract(const Duration(hours: 1)), wasDisplayed: true);
      expect(hungerOnWake(saved, now), closeTo(60, 0.01));
    });

    test('補算不會超過上限，負的時間差當 0 處理', () {
      final long = (hunger: 0.0, savedAt: now.subtract(const Duration(days: 30)), wasDisplayed: true);
      expect(hungerOnWake(long, now), PetStats.maxHunger);
      final future = (hunger: 20.0, savedAt: now.add(const Duration(hours: 5)), wasDisplayed: true);
      expect(hungerOnWake(future, now), 20);
    });
  });

  group('餓度編解碼（含 shown 旗標）', () {
    final at = DateTime(2026, 11, 17, 9, 30);

    test('往返保留餓度、時間點與「收起來」旗標', () {
      final stowed = SettingsRepository.decodeHunger(
        SettingsRepository.encodeHunger(42.5, at, wasDisplayed: false),
      );
      expect(stowed, isNotNull);
      expect(stowed!.hunger, 42.5);
      expect(stowed.savedAt, at);
      expect(stowed.wasDisplayed, isFalse);

      final running = SettingsRepository.decodeHunger(
        SettingsRepository.encodeHunger(10, at),
      );
      expect(running!.wasDisplayed, isTrue, reason: '正常運行的存盤預設是「還在跑」');
    });

    test('舊資料讀得進來：沒有 shown 欄位 → 當「還在跑」（維持升級前的補算行為）', () {
      final old = SettingsRepository.decodeHunger('{"hunger":55,"at":${at.millisecondsSinceEpoch}}');
      expect(old, isNotNull);
      expect(old!.hunger, 55);
      expect(old.savedAt, at);
      expect(old.wasDisplayed, isTrue);
    });

    test('v0 的裸小數格式（無時間點）也讀得進來，當作剛剛寫的', () {
      final legacy = SettingsRepository.decodeHunger('42.00');
      expect(legacy, isNotNull);
      expect(legacy!.hunger, 42);
      expect(legacy.wasDisplayed, isTrue);
    });

    test('壞資料回 null，讓呼叫端決定預設（而不是在這裡猜）', () {
      expect(SettingsRepository.decodeHunger(null), isNull);
      expect(SettingsRepository.decodeHunger('not json'), isNull);
      expect(SettingsRepository.decodeHunger('{"at":123}'), isNull, reason: '缺 hunger 欄位');
      expect(SettingsRepository.decodeHunger('[1,2]'), isNull);
    });
  });
}
