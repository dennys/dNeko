import 'package:flutter_test/flutter_test.dart';
import 'package:dneko/domain/pet_settings.dart';

void main() {
  group('PetSettings', () {
    test('預設值', () {
      const s = PetSettings();
      expect(s.speedPxPerSecond, PetSettings.defaultSpeedPerSecond);
      expect(s.petSize, PetSettings.defaultPetSize);
      expect(s.zone, PetZone.fullScreen);
    });

    test('速度存 px/s，換算成每幀像素（16ms tick）', () {
      const s = PetSettings(speedPxPerSecond: 90);
      expect(s.speedPerTick, closeTo(1.44, 0.0001));
    });

    test('JSON 往返保持一致', () {
      const s = PetSettings(speedPxPerSecond: 150, petSize: 160, zone: PetZone.bottomLeft, hungerMinutesUntilHungry: 30);
      final restored = PetSettings.fromJson(s.toJson());
      expect(restored.speedPxPerSecond, 150);
      expect(restored.petSize, 160);
      expect(restored.zone, PetZone.bottomLeft);
      expect(restored.hungerMinutesUntilHungry, 30);
    });

    test('髒資料：缺欄位/型別不對/不認識的 zone 都回到預設', () {
      final empty = PetSettings.fromJson(const {});
      expect(empty.zone, PetZone.fullScreen);
      expect(empty.petSize, PetSettings.defaultPetSize);

      final junk = PetSettings.fromJson(const {
        'speedPxPerSecond': 'fast',
        'petSize': null,
        'zone': 'moon',
      });
      expect(junk.speedPxPerSecond, PetSettings.defaultSpeedPerSecond);
      expect(junk.petSize, PetSettings.defaultPetSize);
      expect(junk.zone, PetZone.fullScreen);
    });

    test('超出範圍的值被夾住', () {
      final s = PetSettings.fromJson(const {
        'speedPxPerSecond': 9999,
        'petSize': 1,
        'zone': 'bottomBand',
      });
      expect(s.speedPxPerSecond, PetSettings.maxSpeedPerSecond);
      expect(s.petSize, PetSettings.minPetSize);
      expect(s.zone, PetZone.bottomBand);
    });

    test('餓的門檻：預設 60 分鐘，範圍 1~100', () {
      const s = PetSettings();
      expect(s.hungerMinutesUntilHungry, PetSettings.defaultHungerMinutes);
      expect(PetSettings.defaultHungerMinutes, 60);
    });

    test('餓的門檻：髒資料與超範圍都回到合法值', () {
      expect(PetSettings.fromJson(const {}).hungerMinutesUntilHungry, PetSettings.defaultHungerMinutes);
      expect(PetSettings.fromJson(const {'hungerMinutesUntilHungry': 'fast'}).hungerMinutesUntilHungry,
          PetSettings.defaultHungerMinutes);
      expect(PetSettings.fromJson(const {'hungerMinutesUntilHungry': 9999}).hungerMinutesUntilHungry,
          PetSettings.maxHungerMinutes);
      expect(PetSettings.fromJson(const {'hungerMinutesUntilHungry': 0}).hungerMinutesUntilHungry,
          PetSettings.minHungerMinutes);
    });

    test('餓的門檻：copyWith 只改它時其他欄位不動', () {
      const s = PetSettings(speedPxPerSecond: 150);
      final next = s.copyWith(hungerMinutesUntilHungry: 15);
      expect(next.hungerMinutesUntilHungry, 15);
      expect(next.speedPxPerSecond, 150);
    });
  });
}
