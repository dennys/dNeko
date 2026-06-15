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
    required IStoreCatalog catalog,
    required AnimalDownloadService downloadService,
    required IAnimalRepository repository,
  })  : _catalog = catalog,
        _downloadService = downloadService,
        _repository = repository;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    final items = await _catalog.fetchItems();
    final downloaded = await _repository.getAll();
    final downloadedIds = downloaded.map((e) => e.animalId).toSet();

    _items = items
        .map((item) => StoreItemState(
              item: item,
              status: downloadedIds.contains(item.animalId) ? DownloadStatus.downloaded : DownloadStatus.available,
            ))
        .toList();

    _isLoading = false;
    notifyListeners();
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

  Future<void> remove(StoreItem item) async {
    await _downloadService.remove(item.animalId);
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
