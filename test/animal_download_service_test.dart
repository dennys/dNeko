import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dneko/data/models/animal_resource.dart';
import 'package:dneko/data/repositories/i_animal_repository.dart';
import 'package:dneko/data/repositories/settings_repository.dart';
import 'package:dneko/data/services/animal_download_service.dart';

class _FakeRepo implements IAnimalRepository {
  final List<AnimalResource> store = [];
  int upserts = 0;
  final deleted = <String>[];

  @override
  Future<List<AnimalResource>> getAll() async => store;
  @override
  Future<AnimalResource?> getById(String animalId) async =>
      store.where((e) => e.animalId == animalId).cast<AnimalResource?>().firstOrNull;
  @override
  Future<AnimalResource?> resolveResource(String animalId) async => await getById(animalId);
  @override
  Future<void> upsert(AnimalResource resource) async {
    upserts++;
    store.add(resource);
  }

  @override
  Future<void> delete(String animalId) async {
    deleted.add(animalId);
    store.removeWhere((e) => e.animalId == animalId);
  }
}

/// 只用到 deletePetState（刪動物時清親密度/餓度/位置），其餘留著湊介面
class _FakeSettings implements SettingsRepository {
  final deletedBonds = <String>[];

  @override
  Future<void> deletePetState(String animalId) async => deletedBonds.add(animalId);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('這個測試不會用到 ${invocation.memberName}');
}

/// 假伺服器：檔名 → 內容；`failOn` 那個檔在下載中途斷線
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.files, {this.failOn, this.gate});

  final Map<String, String> files;
  final String? failOn;

  /// 給一個還沒 complete 的 Future 就能把下載卡在一個檔上，用來測「下載進行中」的狀態
  final Future<void>? gate;
  final requested = <String>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final url = options.uri.toString();
    requested.add(url);
    await gate;
    if (failOn != null && url.endsWith('/$failOn')) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: '網路斷了',
      );
    }
    final body = files[url];
    if (body == null) return ResponseBody.fromBytes(const <int>[], 404);
    return ResponseBody.fromString(body, 200);
  }
}

void main() {
  const baseUrl = 'https://example.com/animals/fox';
  const files = ['animation.json', 'sit1.png', 'sit2.png'];

  late Directory base;
  late _FakeRepo repo;
  late _FakeSettings settings;

  Directory animalDir() => Directory('${base.path}/animals/fox');

  AnimalDownloadService serviceWith(_FakeAdapter adapter) => AnimalDownloadService(
        repo,
        settings,
        dio: Dio()..httpClientAdapter = adapter,
        documentsDirectory: () async => base,
      );

  setUp(() async {
    base = await Directory.systemTemp.createTemp('dneko-download-test');
    repo = _FakeRepo();
    settings = _FakeSettings();
  });

  tearDown(() async {
    if (await base.exists()) await base.delete(recursive: true);
  });

  Future<void> seedOldAnimal({required List<String> names, required String content}) async {
    final dir = animalDir();
    await dir.create(recursive: true);
    for (final n in names) {
      await File('${dir.path}/$n').writeAsString(content);
    }
  }

  Map<String, String> serverFiles({String content = 'new'}) =>
      {for (final n in files) '$baseUrl/$n': '$content:$n'};

  /// animals/ 底下不該留下的垃圾：任何一集的暫存與換版中途的 .old
  Future<List<String>> leftovers() async {
    final animals = Directory('${base.path}/animals');
    if (!await animals.exists()) return const [];
    return animals
        .listSync()
        .map((e) => e.path.split('/').last)
        .where((n) => n.startsWith('fox.tmp') || n == 'fox.old')
        .toList();
  }

  group('AnimalDownloadService', () {
    test('全部下載完成才換上：目標資料夾的內容就是這次抓的那套', () async {
      final service = serviceWith(_FakeAdapter(serverFiles()));

      final resource = await service.download(
        animalId: 'fox',
        displayName: '小狐狸',
        remoteBaseUrl: baseUrl,
        version: '1.0.0',
        fileNames: files,
      );

      expect(await File('${animalDir().path}/sit2.png').readAsString(), 'new:sit2.png');
      expect(await leftovers(), isEmpty, reason: '暫存要清掉');
      expect(resource.localFolderPath, animalDir().path);
      expect(repo.upserts, 1, reason: '只有換成功這一次才寫 DB');
    });

    test('下載中途斷線：**原本能用的那隻要原封不動**（舊版會先刪一整個資料夾 → 動物整個毀掉）', () async {
      await seedOldAnimal(names: files, content: 'old');

      final service = serviceWith(_FakeAdapter(serverFiles(), failOn: 'sit2.png'));

      await expectLater(
        service.download(
          animalId: 'fox',
          displayName: '小狐狸',
          remoteBaseUrl: baseUrl,
          version: '2.0.0',
          fileNames: files,
        ),
        throwsA(isA<DioException>()),
      );

      expect(await File('${animalDir().path}/sit1.png').readAsString(), 'old',
          reason: '失敗只是這次沒成功，舊素材必須還在');
      expect(await leftovers(), isEmpty,
          reason: '半套的暫存不能留下來吃空間（不論叫什麼名字）');
      expect(repo.upserts, 0, reason: '沒換成功就不能改 DB（否則 DB 指向一個空資料夾）');
    });

    test('換新版本時舊檔不會混進來（舊版靠「先刪一整包」達成，改成暫存換上後仍要成立）', () async {
      await seedOldAnimal(names: [...files, 'gone.png'], content: 'old');

      await serviceWith(_FakeAdapter(serverFiles())).download(
        animalId: 'fox',
        displayName: '小狐狸',
        remoteBaseUrl: baseUrl,
        version: '2.0.0',
        fileNames: files,
      );

      expect(await File('${animalDir().path}/sit1.png').readAsString(), 'new:sit1.png');
      expect(await File('${animalDir().path}/gone.png').exists(), isFalse,
          reason: '新版沒提供的舊檔不能留在資料夾裡被誤用');
    });

    test('伺服器回 200 卻給了 0 bytes 的檔案 → 整個換動作不發生（不能半套上線）', () async {
      // 只檢查「檔名都在」會被這種對端騙過：檔存在但是空的，換上去就是一隻開不了的動物。
      await seedOldAnimal(names: files, content: 'old');
      final server = serverFiles()..['$baseUrl/sit2.png'] = '';

      await expectLater(
        serviceWith(_FakeAdapter(server)).download(
          animalId: 'fox',
          displayName: '小狐狸',
          remoteBaseUrl: baseUrl,
          version: '2.0.0',
          fileNames: files,
        ),
        throwsA(isA<FileSystemException>()),
      );

      expect(await File('${animalDir().path}/sit1.png').readAsString(), 'old');
      expect(repo.upserts, 0);
    });

    test('正在使用的那隻不准刪（刪了 overlay 就永久畫佔位圓）', () async {
      await seedOldAnimal(names: files, content: 'old');
      final service = serviceWith(_FakeAdapter({}));

      await expectLater(
        service.remove('fox', currentAnimalId: 'fox'),
        throwsA(isA<StateError>()),
      );

      expect(await File('${animalDir().path}/sit1.png').readAsString(), 'old',
          reason: '被擋掉就不能已經動手刪檔案');
      expect(settings.deletedBonds, isEmpty);
      expect(repo.deleted, isEmpty);
    });

    test('刪別的動物：資料夾、DB 列、親密度三處一起清乾淨', () async {
      await seedOldAnimal(names: files, content: 'old');
      final service = serviceWith(_FakeAdapter({}));

      await service.remove('fox', currentAnimalId: 'cat');

      expect(await animalDir().exists(), isFalse);
      expect(repo.deleted, ['fox']);
      expect(settings.deletedBonds, ['fox']);
    });
    // 兩趟並行會共用同一個 <id>.tmp：第二趟開頭的「先清掉舊暫存」會把第一趟正在寫的
    // 整包砍掉，最後只拿到一個難看的檔案系統錯誤。所以在入口就擋掉。
    test('同一隻動物同時只准一趟下載（UI 連點兩下就會這樣）', () async {
      final gate = Completer<void>();
      final service = serviceWith(_FakeAdapter(serverFiles(), gate: gate.future));

      final first = service.download(
        animalId: 'fox',
        displayName: '小狐狸',
        remoteBaseUrl: baseUrl,
        version: '1.0.0',
        fileNames: files,
      );
      await pumpEventQueue();

      await expectLater(
        service.download(
          animalId: 'fox',
          displayName: '小狐狸',
          remoteBaseUrl: baseUrl,
          version: '1.0.0',
          fileNames: files,
        ),
        throwsA(isA<StateError>()),
        reason: '第二趟要在入口擋掉，不能進去清掉第一趟正在寫的暫存',
      );

      gate.complete();
      await first;

      expect(await File('${animalDir().path}/sit2.png').readAsString(), 'new:sit2.png',
          reason: '被擋掉的第二趟不能傷到第一趟');
      // 放行的那一下要在 finally 裡：成敗都要歸還，否則失敗過一次就永遠重試不了
      await service.download(
        animalId: 'fox',
        displayName: '小狐狸',
        remoteBaseUrl: baseUrl,
        version: '1.1.0',
        fileNames: files,
      );
      expect(repo.upserts, 2);
    });
  });

  group('promoteDownloaded', () {
    test('暫存整個換到目標位置，目標裡的舊東西不殘留', () async {
      final parent = base;
      final staging = Directory('${parent.path}/staging')..createSync();
      final target = Directory('${parent.path}/target')..createSync();
      File('${staging.path}/new.png').writeAsStringSync('新');
      File('${target.path}/old.png').writeAsStringSync('舊');

      await promoteDownloaded(staging: staging, target: target);

      expect(File('${target.path}/new.png').readAsStringSync(), '新');
      expect(File('${target.path}/old.png').existsSync(), isFalse);
      expect(staging.existsSync(), isFalse);
    });

    test('暫存不存在時丟例外，不會把目標清成空的', () async {
      final staging = Directory('${base.path}/missing');
      final target = Directory('${base.path}/target2')..createSync();
      File('${target.path}/keep.png').writeAsStringSync('留著');

      await expectLater(
        promoteDownloaded(staging: staging, target: target),
        throwsA(isA<FileSystemException>()),
      );

      expect(File('${target.path}/keep.png').existsSync(), isTrue,
          reason: '先檢查暫存在不在，才能避免「舊的已刪、新的搬不過來」');
    });
    // 舊寫法是「先刪 target 再 rename」：那個 rename 一失敗，使用者原本能用的那隻就沒了。
    // 現在是 rename 讓位 → 換上 → 才刪舊的，中途失敗把舊的改名回原位。
    test('換到一半失敗（暫存搬不過去）：舊的素材要放回原位，不能留一個空資料夾', () async {
      final staging = Directory('${base.path}/stagingA')..createSync();
      final target = Directory('${base.path}/targetA')..createSync();
      File('${staging.path}/new.png').writeAsStringSync('新');
      File('${target.path}/keep.png').writeAsStringSync('舊');

      Future<void> rename(Directory from, String to) async {
        if (from.path == staging.path) throw const FileSystemException('搬不過去');
        await from.rename(to);
      }

      await expectLater(
        promoteDownloaded(staging: staging, target: target, rename: rename),
        throwsA(isA<FileSystemException>()),
      );

      expect(File('${target.path}/keep.png').existsSync(), isTrue,
          reason: '換到一半失敗時使用者那隻動物還是開得了');
      expect(File('${target.path}/new.png').existsSync(), isFalse);
      expect(Directory('${target.path}.old').existsSync(), isFalse, reason: '回滾後不該留 .old');
    });

    test('上次死在兩個 rename 之間（正式位置是空的、舊的在 .old）：這次失敗也要把舊的找回來', () async {
      final staging = Directory('${base.path}/stagingB')..createSync();
      File('${staging.path}/new.png').writeAsStringSync('新');
      final target = Directory('${base.path}/targetB'); // 上次死掉 → 正式位置空的
      final old = Directory('${base.path}/targetB.old')..createSync();
      File('${old.path}/keep.png').writeAsStringSync('舊');

      Future<void> rename(Directory from, String to) async {
        if (from.path == staging.path) throw const FileSystemException('搬不過去');
        await from.rename(to);
      }

      await expectLater(
        promoteDownloaded(staging: staging, target: target, rename: rename),
        throwsA(isA<FileSystemException>()),
      );

      expect(File('${target.path}/keep.png').existsSync(), isTrue,
          reason: '.old 是那隻動物最後的一份副本，不能当成垃圾刪掉');
    });
  });
}
