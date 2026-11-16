import 'package:dneko/data/models/animal_resource.dart';
import 'package:dneko/data/repositories/animal_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// DB 讀不到（sqflite 在 overlay isolate 不可用、檔損毀、首次開檔失敗…）時，內建動物還是要
/// 載入得回來 —— `overlay_main._loadAnimal` 就走 `resolveResource` 這一條路，它回 null 的話
/// 懸浮一開只剩佔位圓，連內建的貓都出不來。
class _BrokenDbRepository extends AnimalRepository {
  @override
  Future<AnimalResource?> getById(String animalId) async =>
      throw Exception('sqflite unavailable in isolate');
}

void main() {
  test('DB 壞了：內建動物退回打包進來的素材，不是回 null', () async {
    final resource = await _BrokenDbRepository().resolveResource('cat');
    expect(resource, isNotNull, reason: 'DB 掛了內建動物也必須還在（素材在 assets 裡）');
    expect(resource!.animalId, 'cat');
    expect(resource.isBuiltIn, isTrue);
  });

  test('DB 壞了也不憑空變出下載的動物（素材在本地資料夾，路徑只能問 DB）', () async {
    expect(await _BrokenDbRepository().resolveResource('fox'), isNull);
  });
}
