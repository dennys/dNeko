import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dneko/domain/i_store_catalog.dart';
import 'package:dneko/domain/store_item.dart';
import 'package:dneko/data/repositories/i_animal_repository.dart';
import 'package:dneko/data/repositories/settings_repository.dart';
import 'package:dneko/data/models/animal_resource.dart';
import 'package:dneko/data/services/animal_download_service.dart';
import 'package:dneko/presentation/controllers/store_controller.dart';

class _FakeCatalog implements IStoreCatalog {
  @override
  Future<List<StoreItem>> fetchItems() async => const [
        StoreItem(
          animalId: 'fox',
          displayName: '小狐狸',
          version: '1.0.0',
          remoteBaseUrl: 'https://x/fox',
          thumbnailFrame: 'sit1',
          fileNames: ['animation.json'],
        ),
      ];
}

class _FakeRepository implements IAnimalRepository {
  final List<AnimalResource> store = [];
  @override
  Future<List<AnimalResource>> getAll() async => store;
  @override
  Future<AnimalResource?> getById(String animalId) async =>
      store.where((e) => e.animalId == animalId).cast<AnimalResource?>().firstOrNull;
  @override
  Future<AnimalResource?> resolveResource(String animalId) async => await getById(animalId);
  @override
  Future<void> upsert(AnimalResource resource) async => store.add(resource);
  @override
  Future<void> delete(String animalId) async =>
      store.removeWhere((e) => e.animalId == animalId);
}

/// 只用到 deletePetState（刪動物時清親密度/餓度/位置）—— 真的 SettingsRepository 要開 DB，
/// 單元測試裡開不了。
class _FakeSettings implements SettingsRepository {
  final deletedBonds = <String>[];

  @override
  Future<void> deletePetState(String animalId) async => deletedBonds.add(animalId);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('這個測試不會用到 ${invocation.memberName}');
}

class _BrokenRepository implements IAnimalRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw Exception('DB 壞了');
}

/// 真檔案系統路徑：指向一個暫存目錄，讓 remove() 不會去碰 path_provider 的 platform channel
AnimalDownloadService _service(IAnimalRepository repo, SettingsRepository settings) =>
    AnimalDownloadService(repo, settings, documentsDirectory: () async => Directory.systemTemp);

void main() {
  group('StoreController', () {
    test('載入後標記已下載狀態', () async {
      final repo = _FakeRepository()
        ..store.add(AnimalResource(
          animalId: 'fox',
          displayName: '小狐狸',
          localFolderPath: '/x',
          version: '1.0.0',
          isDownloaded: true,
          isBuiltIn: false,
          updatedAt: DateTime.now(),
        ));

      final controller = StoreController(
        catalog: _FakeCatalog(),
        downloadService: AnimalDownloadService(repo, SettingsRepository()),
        repository: repo,
      );

      await controller.load();

      expect(controller.items, hasLength(1));
      expect(controller.items.first.status, DownloadStatus.downloaded);
    });

    test('DB 讀不到時不會永久轉圈，並把原因交給 downloadError', () async {
      // 以前 load() 沒有 try/finally：_repository.getAll() 一丟例外，isLoading 就永遠是
      // true，商店頁停在一顆轉不完的轉圈圖上，連錯誤訊息都看不到。
      final controller = StoreController(
        catalog: _FakeCatalog(),
        downloadService: AnimalDownloadService(_FakeRepository(), SettingsRepository()),
        repository: _BrokenRepository(),
      );

      await controller.load();

      expect(controller.isLoading, isFalse, reason: '不管成不成功都要收掉轉圈');
      expect(controller.downloadError, isNotNull, reason: '要讓畫面看得到原因');
    });

    test('未下載時為 available', () async {
      final repo = _FakeRepository();
      final controller = StoreController(
        catalog: _FakeCatalog(),
        downloadService: AnimalDownloadService(repo, SettingsRepository()),
        repository: repo,
      );

      await controller.load();

      expect(controller.items.first.status, DownloadStatus.available);
    });

    test('刪掉正在使用的那隻：被擋掉、狀態不變、錯誤訊息送出去', () async {
      // 刪掉使用者現在養的那隻 = overlay 那側 resolveResource 拿到 null，
      // 而下載過的動物不在內建清單裡 → 寵物永久變佔位圓。要在這裡就擋住。
      final repo = _FakeRepository()
        ..store.add(AnimalResource(
          animalId: 'fox',
          displayName: '小狐狸',
          localFolderPath: '/x',
          version: '1.0.0',
          isDownloaded: true,
          isBuiltIn: false,
          updatedAt: DateTime.now(),
        ));
      final settings = _FakeSettings();
      final controller = StoreController(
        catalog: _FakeCatalog(),
        downloadService: _service(repo, settings),
        repository: repo,
        currentAnimalId: () => 'fox',
      );
      await controller.load();
      expect(controller.items.first.status, DownloadStatus.downloaded);

      await controller.remove(controller.items.first.item);

      expect(controller.items.first.status, DownloadStatus.downloaded,
          reason: '被擋掉就不能把清單改顯示成「尚未下載」');
      expect(controller.downloadError, contains('正在使用中'));
    });

    test('刪掉別的動物仍舊正常（狀態回到 available、親密度一起清）', () async {
      final repo = _FakeRepository();
      final settings = _FakeSettings();
      final controller = StoreController(
        catalog: _FakeCatalog(),
        downloadService: _service(repo, settings),
        repository: repo,
        currentAnimalId: () => 'cat',
      );
      await controller.load();

      await controller.remove(controller.items.first.item);

      expect(controller.items.first.status, DownloadStatus.available);
      expect(controller.downloadError, isNull);
      expect(settings.deletedBonds, ['fox'], reason: '親密度那列 KV 不在 animals 表裡，只能靠這條路清');
    });
  });
}