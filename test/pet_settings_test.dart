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
      const s = PetSettings(speedPxPerSecond: 150, petSize: 160, zone: PetZone.bottomLeft);
      final restored = PetSettings.fromJson(s.toJson());
      expect(restored.speedPxPerSecond, 150);
      expect(restored.petSize, 160);
      expect(restored.zone, PetZone.bottomLeft);
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
  });
}
