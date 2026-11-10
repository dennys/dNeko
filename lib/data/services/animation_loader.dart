import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../models/animation_definition.dart';
import '../models/animal_resource.dart';

class AnimationLoader {
  /// 載入動畫定義（自動判斷內建 or 已下載）
  Future<AnimalAnimationDefinition> load(AnimalResource resource) async {
    _refreshIfReplaced(resource);
    return resource.isBuiltIn ? _loadFromAssets(resource.animalId) : _loadFromFile(resource.localFolderPath);
  }

  /// 來源指紋。同一 animalId 重新下載（蓋同一個資料夾）之後，檔案路徑完全沒變，
  /// 而 Flutter 的 ImageCache 是按 provider 的 `==`（FileImage 就是比檔名）索引的 ——
  /// 不清掉的話這個 isolate 會一直顯示舊圖，直到重開 app。
  String _fingerprint(AnimalResource resource) =>
      '${resource.version}|${resource.localFolderPath}|${resource.updatedAt.millisecondsSinceEpoch}';
  final Map<String, String> _fingerprints = {};

  /// 偵測到「這隻被換過了」就把它目前的圖片趕出快取：本 loader 的 provider 快取與
  /// Flutter 的全域 ImageCache 都要趕，只清一個沒用（另一個還是會給舊的解碼結果）。
  void _refreshIfReplaced(AnimalResource resource) {
    final id = resource.animalId;
    final previous = _fingerprints[id];
    final current = _fingerprint(resource);
    _fingerprints[id] = current;
    if (previous == null || previous == current) return;

    final folderPrefix = 'file:${resource.localFolderPath}/';
    final assetPrefix = 'asset:animals/$id/';
    final stale = _providerCache.keys
        .where((k) => k.startsWith(folderPrefix) || k.startsWith(assetPrefix))
        .toList();
    for (final key in stale) {
      final provider = _providerCache.remove(key);
      if (provider != null) PaintingBinding.instance.imageCache.evict(provider);
    }
  }

  Future<AnimalAnimationDefinition> _loadFromAssets(String animalId) async {
    final jsonStr = await rootBundle.loadString(
      'assets/animals/$animalId/animation.json',
    );
    return AnimalAnimationDefinition.fromJson(jsonDecode(jsonStr));
  }

  Future<AnimalAnimationDefinition> _loadFromFile(String folderPath) async {
    final file = File('$folderPath/animation.json');

    if (!await file.exists()) {
      throw FileSystemException('找不到動畫描述檔', file.path);
    }

    final jsonStr = await file.readAsString();
    return AnimalAnimationDefinition.fromJson(jsonDecode(jsonStr));
  }

  /// ImageProvider 一定要穩定：動物的來源在執行期不會變，但 `AnimalAnimator.build()`
  /// 每次重繪都 new 一個 AssetImage/FileImage 的話，Flutter 就視為「換了一張圖」，
  /// 每幀都發生舊 provider 被 evict、新 provider 重新讀檔解碼 —— 桌寵最不該做的事。
  /// Flutter 是用 provider 的 == 做快取的，所以要由這裡保證同一來源同一實例。
  final Map<String, ImageProvider> _providerCache = {};

  /// 取得圖片 ImageProvider（自動判斷來源）
  ImageProvider getFrameImage(AnimalResource resource, String frameName) {
    final key = resource.isBuiltIn
        ? 'asset:animals/${resource.animalId}/$frameName.png'
        : 'file:${resource.localFolderPath}/$frameName.png';
    return _providerCache.putIfAbsent(
      key,
      () => resource.isBuiltIn
          ? AssetImage('assets/animals/${resource.animalId}/$frameName.png')
          : FileImage(File('${resource.localFolderPath}/$frameName.png')),
    );
  }

  // 只有 overlay isolate 會畫動物（AnimalAnimator 只在那邊用），而它用的就是這個 loader
  // 實例，所以「同 isolate 內換圖」在這裡就處理完了。真要做即時換圖給已經開著的懸浮，
  // 主 app 下載完成時推 payload（pushSettings → _onData 看到 animalId 變了會 _loadAnimal）
  // 就能做到 —— 路徑是通的，只是 store 入口目前是關的（kStoreEnabled），用不到。
}
