import '../../domain/i_store_catalog.dart';
import '../../domain/store_item.dart';

/// 只負責：提供靜態（內建）的可下載動物清單
class StaticStoreCatalog implements IStoreCatalog {
  static const _baseUrl = 'https://example.com/animals';

  @override
  Future<List<StoreItem>> fetchItems() async {
    return const [
      StoreItem(
        animalId: 'fox',
        displayName: '小狐狸',
        version: '1.0.0',
        remoteBaseUrl: '$_baseUrl/fox',
        thumbnailFrame: 'sit1',
        fileNames: [
          'animation.json',
          'walk_u1.png', 'walk_u2.png',
          'walk_d1.png', 'walk_d2.png',
          'sit1.png', 'sit2.png',
          'sleep1.png', 'sleep2.png',
        ],
      ),
      StoreItem(
        animalId: 'penguin',
        displayName: '小企鵝',
        version: '1.0.0',
        remoteBaseUrl: '$_baseUrl/penguin',
        thumbnailFrame: 'sit1',
        fileNames: [
          'animation.json',
          'walk_u1.png', 'walk_u2.png',
          'walk_d1.png', 'walk_d2.png',
          'sit1.png', 'sit2.png',
          'sleep1.png', 'sleep2.png',
        ],
      ),
    ];
  }
}