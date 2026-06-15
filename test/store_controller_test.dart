import 'package:flutter_test/flutter_test.dart';
import 'package:dneko/domain/i_store_catalog.dart';
import 'package:dneko/domain/store_item.dart';
import 'package:dneko/data/repositories/i_animal_repository.dart';
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
  Future<List<AnimalResource>> getDownloaded() async => store;
  @override
  Future<AnimalResource?> getById(String animalId) async =>
      store.where((e) => e.animalId == animalId).cast<AnimalResource?>().firstOrNull;
  @override
  Future<void> upsert(AnimalResource resource) async => store.add(resource);
  @override
  Future<void> delete(String animalId) async =>
      store.removeWhere((e) => e.animalId == animalId);
}

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
        downloadService: AnimalDownloadService(repo),
        repository: repo,
      );

      await controller.load();

      expect(controller.items, hasLength(1));
      expect(controller.items.first.status, DownloadStatus.downloaded);
    });

    test('未下載時為 available', () async {
      final repo = _FakeRepository();
      final controller = StoreController(
        catalog: _FakeCatalog(),
        downloadService: AnimalDownloadService(repo),
        repository: repo,
      );

      await controller.load();

      expect(controller.items.first.status, DownloadStatus.available);
    });
  });
}