import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/animal_resource.dart';
import '../repositories/i_animal_repository.dart';
import '../repositories/settings_repository.dart';

/// 把下載好的動物素材包放進本地資料夾的單一入口。
///
/// 兩個注入點（`dio`、`documentsDirectory`）是為了讓「下載到一半斷線會不會毀掉原本能用的
/// 那隻動物」這種事能被測試打 —— 那正是這條路以前踩過的坑。
class AnimalDownloadService {
  final IAnimalRepository _repository;

  /// 刪動物時要連它的親密度列一起清（那不在 animals 表裡，而在 settings KV）
  final SettingsRepository _settings;
  final Future<Directory> Function() _documentsDirectory;

  /// 同一隻動物同時只准有一趟下載：兩趟共用 `<id>.tmp`，第二趟開頭的「先清掉舊暫存」
  /// 會把第一趟正在寫的整包砍掉，而 UI 連點兩下下載就會這樣。放第二趟進來只會拿到一個
  /// 難看的檔案系統錯誤，所以在入口就擋掉。
  final Set<String> _inFlight = {};

  // 沒設 timeout 的話，對端吊住就會讓下載永遠卡著（UI 的進度條也不會動）。
  // 建得遲一點：商店入口目前是關的（kStoreEnabled），開著 app 不該先建好一套 HTTP client。
  Dio? _injectedDio;
  Dio? _ownDio;
  Dio get _dio => _injectedDio ??= _ownDio ??= Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 60),
      ));

  AnimalDownloadService(
    this._repository,
    this._settings, {
    Dio? dio,
    Future<Directory> Function()? documentsDirectory,
  })  : _injectedDio = dio,
        _documentsDirectory = documentsDirectory ?? getApplicationDocumentsDirectory;

  /// 下載動物素材包
  /// [remoteBaseUrl] 例如: https://example.com/animals/dog
  ///
  /// 流程是「先進暫存目錄 → 全部驗完 → 才換上」。**不能先刪舊的再抓**：那樣網路在第 3 張圖
  /// 斷掉時，舊的沒了、新的不完整、`upsert` 也不會跑（DB 那列仍指向那個已經被清空的資料夾），
  /// 這隻動物就從此只能畫佔位圓。先进暫存的話，失敗就只是「這次沒成功」，舊的那隻照用。
  Future<AnimalResource> download({
    required String animalId,
    required String displayName,
    required String remoteBaseUrl,
    required String version,
    required List<String> fileNames, // ["animation.json", "up1.png", ...]
    void Function(double progress)? onProgress,
  }) async {
    if (!_inFlight.add(animalId)) {
      throw StateError('$animalId 正在下載了，請等這一趟結束再按');
    }
    try {
      return await _downloadLocked(
        animalId: animalId,
        displayName: displayName,
        remoteBaseUrl: remoteBaseUrl,
        version: version,
        fileNames: fileNames,
        onProgress: onProgress,
      );
    } finally {
      _inFlight.remove(animalId); // 成敗都要放行下一趟（失敗之後要能重試）
    }
  }

  Future<AnimalResource> _downloadLocked({
    required String animalId,
    required String displayName,
    required String remoteBaseUrl,
    required String version,
    required List<String> fileNames,
    void Function(double progress)? onProgress,
  }) async {
    final target = await _resolveLocalFolder(animalId);
    final staging = Directory('${target.path}.tmp');
    await _deleteQuietly(staging); // 上次沒清掉的殘留先清掉，免得混進這一次的驗收
    await staging.create(recursive: true);

    try {
      for (var i = 0; i < fileNames.length; i++) {
        final fileName = safeName(fileNames[i], 'fileNames[$i]');
        await _dio.download(
          '$remoteBaseUrl/$fileName',
          p.join(staging.path, fileName),
        );
        onProgress?.call((i + 1) / fileNames.length);
      }

      // 只檢查「檔名都在」—— 半套（有.animation.json 卻缺圖）在這一步就會被擋掉，
      // 也不會因為「舊的還在」而混過關（舊的從未進過這個暫存目錄）。
      _verifyAssets(staging.path, fileNames);
      await promoteDownloaded(staging: staging, target: target);
    } catch (_) {
      await _deleteQuietly(staging); // 半套的暫存留著沒用，只會吃空間
      rethrow;
    }

    final resource = AnimalResource(
      animalId: animalId,
      displayName: displayName,
      localFolderPath: target.path,
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
  ///
  /// [currentAnimalId] 是使用者現在選的那隻：**正在用的那隻不准刪** —— 刪掉之後
  /// settings.animalId 還指著它，而下載過的動物不在內建清單裡，overlay 就永久畫佔位圓。
  Future<void> remove(String animalId, {String? currentAnimalId}) async {
    if (currentAnimalId != null && currentAnimalId == animalId) {
      throw StateError('這隻動物正在使用中，先在主頁換一隻再刪');
    }
    final folder = await _resolveLocalFolder(animalId);
    if (await folder.exists()) {
      await folder.delete(recursive: true);
    }
    // 暫存與 .old 也可能有殘留（下載被殺在中間、或清暫存時失敗留下的）
    await _deleteLeftovers(folder);
    await _repository.delete(animalId);
    // 親密度是「每隻動物一列 KV」（pet_bond_<id>），不在這條唯一的刪除路徑上清掉就沒人清了
    await _settings.deletePetState(animalId);
  }

  /// 確認所有檔案都真的下載到了，避免半套素材。
  ///
  /// 「存在」不夠：對端回 200 卻給 0 bytes（壞掉的 CDN／ proxy 擋掉）時檔名是齊的，
  /// 換上去之後就是「有 animation.json 但內容是空的」那類最難查的佔位圓。
  void _verifyAssets(String folderPath, List<String> fileNames) {
    for (final fileName in fileNames) {
      final file = File(p.join(folderPath, fileName));
      if (!file.existsSync() || file.lengthSync() == 0) {
        throw FileSystemException('素材下載不完整', file.path);
      }
    }
  }

  /// 清掉 `<id>.tmp*` 與 `<id>.old` 的殘留（下載中途被殺、或換版死在兩個 rename 之間）。
  /// 掃不乾淨只是多佔一點空間，不能讓刪動物變成失敗。
  Future<void> _deleteLeftovers(Directory target) async {
    try {
      final parent = target.parent;
      if (!await parent.exists()) return;
      final base = p.basename(target.path);
      await for (final entry in parent.list()) {
        final name = p.basename(entry.path);
        if (name == '$base.old' || name == '$base.tmp' || name.startsWith('$base.tmp-')) {
          await entry.delete(recursive: true);
        }
      }
    } catch (_) {
      // 見上
    }
  }

  Future<Directory> _resolveLocalFolder(String animalId) async {
    final base = await _documentsDirectory();
    return Directory(p.join(base.path, 'animals', safeName(animalId, 'animalId')));
  }
}

Future<void> _deleteQuietly(Directory dir) async {
  try {
    if (await dir.exists()) await dir.delete(recursive: true);
  } catch (_) {
    // 清不掉只是多佔一點空間，不能讓它變成下載/刪除失敗的理由
  }
}

/// 把驗好的暫存目錄換成正式的。
///
/// 順序是「舊的**改名**讓位 → 暫存取代 → 才真的刪舊的」，不是「先刪舊的再搬」：
/// 后者在中途失敗時會把使用者原本能用的那隻動物一起帶走。換到一半丟例外就把舊的改名
/// 放回原位。
///
/// [rename] 是測試縫隙（假的換名才能打「換到一半失敗」那條路，真檔案系統沒辦法），
/// 正產碼一律用它預設的 `Directory.rename`：同一個父目錄 → 同盤，不會跨裝置失敗。
Future<void> promoteDownloaded({
  required Directory staging,
  required Directory target,
  Future<void> Function(Directory from, String to)? rename,
}) async {
  Future<void> move(Directory from, String to) => rename != null
      ? rename(from, to)
      : from.rename(to).then((_) {});

  if (!await staging.exists()) {
    throw FileSystemException('暫存目錄不存在，沒有東西可以換上', staging.path);
  }
  final old = Directory('${target.path}.old');
  if (await old.exists()) {
    if (!await target.exists()) {
      // 上次死在兩個 rename 之間：舊素材還住在 .old，先幫它回原位，別當垃圾刪了
      await move(old, target.path);
    } else {
      await _deleteQuietly(old); // 這次本來就要換掉 target，殘留的 .old 沒用了
    }
  }
  if (!await target.exists()) {
    await move(staging, target.path);
    return;
  }
  await move(target, old.path);
  try {
    await move(staging, target.path);
  } catch (_) {
    await move(old, target.path); // 換到一半失敗：舊的放回原位，別留下空資料夾
    rethrow;
  }
  await _deleteQuietly(old); // 換成功了才真的刪舊的
}

/// animalId 與檔名未來會來自遠端 catalogue，先擋掉 `..`、絕對路徑與路徑分隔字元，
/// 免得 p.join 把檔案寫到 animals/ 以外（目前 catalog 寫死在靜態檔，這是預防措施）。
/// 公開成 top-level 純函式好讓單元測試直接打（path traversal 守門員不能沒有測試）。
String safeName(String value, String field) {
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
