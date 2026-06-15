import 'store_item.dart';

/// 提供商店可下載清單（可換成遠端 API 實作）
abstract interface class IStoreCatalog {
  Future<List<StoreItem>> fetchItems();
}