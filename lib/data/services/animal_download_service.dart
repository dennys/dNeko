import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/animal_resource.dart';
import '../repositories/i_animal_repository.dart';

class AnimalDownloadService {
  final IAnimalRepository _repository;
  final Dio _dio;

  AnimalDownloadService(this._repository) : _dio = Dio();

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
    await localFolder.create(recursive: true);

    for (var i = 0; i < fileNames.length; i++) {
      final fileName = fileNames[i];
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
    return Directory(p.join(base.path, 'animals', animalId));
  }
}