import 'package:flutter/foundation.dart';
import '../../domain/i_store_catalog.dart';
import '../../domain/store_item.dart';
import '../../data/services/animal_download_service.dart';
import '../../data/repositories/i_animal_repository.dart';

enum DownloadStatus { available, downloading, downloaded }

class StoreItemState {
  final StoreItem item;
  final DownloadStatus status;
  final double progress; // 0..1

  const StoreItemState({
    required this.item,
    this.status = DownloadStatus.available,
    this.progress = 0,
  });

  StoreItemState copyWith({DownloadStatus? status, double? progress}) => StoreItemState(
        item: item,
        status: status ?? this.status,
        progress: progress ?? this.progress,
      );
}

/// 協調商店清單、下載服務與本地資料庫
class StoreController extends ChangeNotifier {
  final IStoreCatalog _catalog;
  final AnimalDownloadService _downloadService;
  final IAnimalRepository _repository;

  /// 使用者目前選的動物（由外部注入，通常是 `() => settingsController.settings.animalId`）。
  /// 刪掉正在用的那隻會讓 overlay  permanently 畫佔位圓，所以刪除前要問它。
  final String Function() _currentAnimalId;

  List<StoreItemState> _items = [];
  List<StoreItemState> get items => _items;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _downloadError;
  String? get downloadError => _downloadError;
  void clearDownloadError() {
    _downloadError = null;
  }

  StoreController({
    required this._catalog,
    required this._downloadService,
    required this._repository,
    String Function()? currentAnimalId,
  }) : _currentAnimalId = currentAnimalId ?? (() => '');

  /// 抓清單。**一定**要把 isLoading 收掉：以前 DB 一丟例外就永遠是 true，
  /// 商店頁就永久轉圈（連錯誤訊息都看不到）。
  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      final items = await _catalog.fetchItems();
      final downloaded = await _repository.getAll();
      final downloadedIds = downloaded.map((e) => e.animalId).toSet();

      _items = items
          .map((item) => StoreItemState(
                item: item,
                status: downloadedIds.contains(item.animalId) ? DownloadStatus.downloaded : DownloadStatus.available,
              ))
          .toList();
    } catch (e) {
      // 讓畫面收得到原因，而不是停在一顆永遠轉不完的轉圈圖
      _downloadError = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> download(StoreItem item) async {
    _updateState(item.animalId, (s) => s.copyWith(status: DownloadStatus.downloading, progress: 0));

    try {
      await _downloadService.download(
        animalId: item.animalId,
        displayName: item.displayName,
        remoteBaseUrl: item.remoteBaseUrl,
        version: item.version,
        fileNames: item.fileNames,
        onProgress: (p) => _updateState(
          item.animalId,
          (s) => s.copyWith(progress: p),
        ),
      );
      _updateState(item.animalId, (s) => s.copyWith(status: DownloadStatus.downloaded, progress: 1));
    } catch (e) {
      _updateState(item.animalId, (s) => s.copyWith(status: DownloadStatus.available, progress: 0));
      _downloadError = e.toString();
      notifyListeners();
    }
  }

  /// 刪除。**正在使用的那隻不能刪**（服務端會丟 StateError），失敗時保留原狀態並把原因
  /// 交給 `downloadError`，否則清單會顯示「已下載」而檔案其實還在。
  Future<void> remove(StoreItem item) async {
    try {
      await _downloadService.remove(item.animalId, currentAnimalId: _currentAnimalId());
    } catch (e) {
      _downloadError = e.toString();
      notifyListeners();
      return;
    }
    _updateState(item.animalId, (s) => s.copyWith(status: DownloadStatus.available, progress: 0));
  }

  void _updateState(
    String animalId,
    StoreItemState Function(StoreItemState) update,
  ) {
    _items = _items.map((s) => s.item.animalId == animalId ? update(s) : s).toList();
    notifyListeners();
  }
}
