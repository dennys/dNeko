import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dneko/data/repositories/animal_repository.dart';
import 'package:dneko/data/services/animal_sound.dart';
import 'package:dneko/domain/pet_behavior.dart';
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

    test('表裡的音效檔都存在於 assets/（逐個內建動物掃，不是只點名幾隻）', () {
      // 以前這裡寫死 ['cat','dog']：新增一行音效卻忘了放 mp3，測試照綠 ——
      // 而在 app 裡的症狀是「按了沒聲音」，最難查。現在只要有進表就必須有檔。
      final checked = <String>[];
      for (final animal in AnimalRepository.builtIns) {
        final path = touchSoundFor(animal.animalId);
        if (path == null) continue;
        checked.add(path);
        expect(File('assets/$path').existsSync(), isTrue, reason: '${animal.animalId} → $path');
      }
      expect(checked, isNotEmpty, reason: '一個音效都沒掃到＝對應表空了或讀不到 assets/');
    });

    test('討食／裝死用壓低的同一聲：裝死比討食更低，且都在聽得出來又沒慢到變形區間', () {
      expect(hungerCryRate(PetBehavior.beg), lessThan(1.0));
      expect(hungerCryRate(PetBehavior.faint), lessThan(hungerCryRate(PetBehavior.beg)));
      for (final behavior in [PetBehavior.beg, PetBehavior.faint]) {
        expect(hungerCryRate(behavior), inInclusiveRange(0.5, 0.95), reason: '$behavior');
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
