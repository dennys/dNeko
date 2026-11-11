import 'package:audioplayers/audioplayers.dart';

/// 只負責：播放一段音效檔（抽成介面，方便測試時換成假的）
abstract interface class ISoundPlayer {
  Future<void> play(String assetPath);
  Future<void> dispose();
}

class AudioPlayerSoundPlayer implements ISoundPlayer {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> play(String assetPath) async {
    try {
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
