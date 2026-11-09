import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/animal_resource.dart';
import '../repositories/i_animal_repository.dart';

class AnimalDownloadService {
  final IAnimalRepository _repository;
  final Dio _dio;

  // 沒設 timeout 的話，對端吊住就會讓下載永遠卡著（UI 的進度條也不會動）
  AnimalDownloadService(this._repository)
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 60),
        ));

  /// 下載動物素材包
  /// [remoteBaseUrl] 例如: https://example.com/animals/dog
  Future<AnimalResource> download({
    required String animalId,
    required String displayName,
    required String remoteBaseUrl,
    required String version,
    required List<String> fileNames, // ["animation.json", "up1.png", ...]
    void Function(double progress)? onProgress,
  }) async {
    final localFolder = await _resolveLocalFolder(animalId);
    // Wipe the folder first: a re-download that fails halfway used to leave
    // new animation.json next to old frames, and _verifyAssets only checks that
    // every file name exists, so that mixed set passed verification.
    if (await localFolder.exists()) {
      await localFolder.delete(recursive: true);
    }
    await localFolder.create(recursive: true);

    for (var i = 0; i < fileNames.length; i++) {
      final fileName = _safeName(fileNames[i], 'fileNames[$i]');
      await _dio.download(
        '$remoteBaseUrl/$fileName',
        p.join(localFolder.path, fileName),
      );
      onProgress?.call((i + 1) / fileNames.length);
    }

    _verifyAssets(localFolder.path, fileNames);

    final resource = AnimalResource(
      animalId: animalId,
      displayName: displayName,
      localFolderPath: localFolder.path,
      version: version,
      isDownloaded: true,
      isBuiltIn: false,
      updatedAt: DateTime.now(),
    );

    await _repository.upsert(resource);
    return resource;
  }

  /// 刪除已下載的動物
  /// animalId 會進檔案路徑，與 download() 用同一套白名單檢查
  /// fileNames 給空清單時會驗證出「全部檔案都存在」（= 什麼都沒下載也算成功），
  /// 商店那側至少要知道這件事；目前清單寫死在 StaticStoreCatalog，不會發生。
  Future<void> remove(String animalId) async {
    final folder = await _resolveLocalFolder(animalId);
    if (await folder.exists()) {
      await folder.delete(recursive: true);
    }
    await _repository.delete(animalId);
  }

  /// 確認所有檔案都已下載完成，避免半套素材
  void _verifyAssets(String folderPath, List<String> fileNames) {
    for (final fileName in fileNames) {
      final file = File(p.join(folderPath, fileName));
      if (!file.existsSync()) {
        throw FileSystemException('素材下載不完整', file.path);
      }
    }
  }

  Future<Directory> _resolveLocalFolder(String animalId) async {
    final base = await getApplicationDocumentsDirectory();
    return Directory(p.join(base.path, 'animals', _safeName(animalId, 'animalId')));
  }
}

/// animalId 與檔名未來會來自遠端 catalogue，先擋掉 `..`、絕對路徑與路徑分隔字元，
/// 免得 p.join 把檔案寫到 animals/ 以外（目前 catalog 寫死在靜態檔，這是預防措施）。
String _safeName(String value, String field) {
  if (value.isEmpty ||
      value == '.' ||
      value == '..' ||
      value.contains('/') ||
      value.contains('\\') ||
      p.isAbsolute(value)) {
    throw ArgumentError.value(value, field, '不合法的識別碼或檔名');
  }
  return value;
}