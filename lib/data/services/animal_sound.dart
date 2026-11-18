import 'package:audioplayers/audioplayers.dart';

import '../../domain/pet_behavior.dart';

/// 只負責：播放一段音效檔（抽成介面，方便測試時換成假的）
abstract interface class ISoundPlayer {
  /// [rate] 是播放倍速（1 = 原速）。討食／裝死用 [hungerCryRate] 的低倍速：聽得出來變低沉，
  /// 又不會慢到聽成另一種動物。每次播放都照傳進來的倍速設定，事後的播放才不會被上一次帶著走。
  Future<void> play(String assetPath, {double rate = 1.0});
  Future<void> dispose();
}

class AudioPlayerSoundPlayer implements ISoundPlayer {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> play(String assetPath, {double rate = 1.0}) async {
    try {
      await _player.setPlaybackRate(rate);
      // AssetSource 的路徑相對於 assets/
      await _player.play(AssetSource(assetPath));
    } catch (_) {
      // 音效失敗不該影響寵物本身（例如 plugin 尚未就緒）
    }
  }

  @override
  Future<void> dispose() => _player.dispose();
}

/// 內建動物的「摸一下」叫聲，路徑相對於 assets/。沒列在這裡的動物（如下載的）不出聲。
const Map<String, String> _touchSoundByAnimal = {
  'cat': 'animals/cat/meow.mp3',
  'cat2': 'animals/cat/meow.mp3',
  'dog': 'animals/dog/bark.mp3',
  'heart_dog': 'animals/dog/bark.mp3',
};

/// 回傳該動物摸一下要播的音效路徑；沒有音效回傳 null
String? touchSoundFor(String animalId) => _touchSoundByAnimal[animalId];

/// 討食／裝死的叫聲倍速：**不另做音效檔**，直接把同一聲叫聲壓低 —— 聽得出來在委屈，
/// 又不會慢到聽成另一種動物。裝死比討食更垮，所以更低。
/// 倍速能不能設成功由 [ISoundPlayer.play] 吞掉（audioplayers 不支援時也不能影響寵物本身）。
double hungerCryRate(PetBehavior behavior) => behavior == PetBehavior.faint ? 0.6 : 0.75;
