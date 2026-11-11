import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dneko/data/services/animal_sound.dart';
import 'package:dneko/domain/pet_settings.dart';

void main() {
  group('叫聲音效', () {
    test('有提供音效的內建動物回傳路徑，其餘回傳 null', () {
      expect(touchSoundFor('cat'), 'animals/cat/meow.mp3');
      expect(touchSoundFor('cat2'), 'animals/cat/meow.mp3');
      expect(touchSoundFor('dog'), 'animals/dog/bark.mp3');
      expect(touchSoundFor('heart_dog'), 'animals/dog/bark.mp3');
      expect(touchSoundFor('penguin'), isNull);
      expect(touchSoundFor('downloaded_unknown'), isNull);
    });

    test('對應的音效檔都存在於 assets/', () {
      for (final id in ['cat', 'dog']) {
        final path = touchSoundFor(id)!;
        expect(File('assets/$path').existsSync(), isTrue, reason: path);
      }
    });
  });

  group('soundEnabled 設定', () {
    test('預設關閉', () {
      expect(const PetSettings().soundEnabled, isFalse);
    });

    test('JSON 往返保留，缺欄位或型別錯誤回到關閉', () {
      final on = const PetSettings().copyWith(soundEnabled: true);
      expect(PetSettings.fromJson(on.toJson()).soundEnabled, isTrue);
      expect(PetSettings.fromJson({'soundEnabled': 'yes'}).soundEnabled, isFalse);
      expect(PetSettings.fromJson({}).soundEnabled, isFalse);
    });
  });
}
