/// 商店中可下載的動物項目
class StoreItem {
  final String animalId;
  final String displayName;
  final String version;
  final String remoteBaseUrl;
  final List<String> fileNames; // 需下載的檔案清單
  final String thumbnailFrame; // 預覽圖檔名（不含副檔名）

  const StoreItem({
    required this.animalId,
    required this.displayName,
    required this.version,
    required this.remoteBaseUrl,
    required this.fileNames,
    required this.thumbnailFrame,
  });
}