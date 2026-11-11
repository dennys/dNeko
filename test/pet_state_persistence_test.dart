import 'dart:convert';
import 'dart:io';

import 'package:dneko/data/models/animal_resource.dart';
import 'package:dneko/data/repositories/animal_repository.dart';
import 'package:dneko/data/repositories/settings_repository.dart';
import 'package:dneko/data/services/animation_loader.dart';
import 'package:dneko/domain/pet_stats.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('內建動物清單', () {
    // 這一組守的是同一類 bug：素材明明在 repo 裡，卻因為清單沒對齊而永遠用不到
    // （之前 assets/animals/dog/ 存在、overlay 也認得 dog，但 seedBuiltIns 只塞 cat
    //   → 主頁選單讀 getAll()，小柴犬永遠選不到）。
    test('assets/animals 下的每一隻都要註冊成內建', () {
      final bundled = Directory('assets/animals')
          .listSync()
          .whereType<Directory>()
          // 只有 animation.json、圖還沒產的資料夾還不算「一隻可用的動物」
          .where((d) => d.listSync().whereType<File>().any((f) => f.path.endsWith('.png')))
          .map((e) => p.basename(e.path))
          .toSet();
      final registered = AnimalRepository.builtIns.map((a) => a.animalId).toSet();

      expect(bundled.difference(registered), isEmpty, reason: '素材打包了卻沒註冊 → 使用者選不到');
      expect(registered.difference(bundled), isEmpty, reason: '註冊了卻沒有素材 → 載入一定失敗');
    });

    test('每一隻內建的素材與 pubspec 的 assets 清單都要對得上', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final animal in AnimalRepository.builtIns) {
        expect(File('assets/animals/${animal.animalId}/animation.json').existsSync(), isTrue,
            reason: '${animal.animalId} 沒有 animation.json');
        expect(pubspec, contains('assets/animals/${animal.animalId}/'),
            reason: '${animal.animalId} 沒列進 pubspec 的 assets → rootBundle 讀不到');
        expect(animal.displayName.trim(), isNotEmpty);
      }
    });
  });

  group('getAll 的合併（內建不再依賴 seed）', () {
    // REVIEW #6：之前內建動物要「註冊 builtIns ＋ pubspec assets ＋ bump petDbVersion」
    // 三件一起做才選得到，而 bump 那件沒有任何測試擋 —— 漏掉時 analyze 綠、測試全過，
    // 舊安裝的選單卻永遠看不到新動物。現在 getAll = DB 列 ∪ builtIns，這裡鎖住合併規則。
    AnimalResource a(String id, {String name = '', bool downloaded = false, String version = '1.0.0'}) =>
        AnimalResource(
          animalId: id,
          displayName: name.isEmpty ? id : name,
          localFolderPath: downloaded ? '/data/$id' : '',
          version: version,
          isDownloaded: downloaded,
          isBuiltIn: !downloaded,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
        );

    test('DB 是空的（舊安裝、還沒 seed）也要看得到全部內建', () {
      final merged = AnimalRepository.mergeBuiltIns([], AnimalRepository.builtIns);

      expect(merged.map((e) => e.animalId),
          containsAll(AnimalRepository.builtIns.map((e) => e.animalId)));
      expect(merged.any((e) => e.animalId == 'sloth'), isTrue,
          reason: '最後加進來的內建 —— 舊安裝 DB 裡沒有它，靠的就是這條');
    });

    test('同 id 時 DB 那份贏（下載/改過的資料不被內建定義蓋掉）', () {
      final merged = AnimalRepository.mergeBuiltIns(
        [a('cat', name: '我的貓', downloaded: true, version: '2.1.0')],
        AnimalRepository.builtIns,
      );

      final cat = merged.singleWhere((e) => e.animalId == 'cat');
      expect(cat.displayName, '我的貓');
      expect(cat.version, '2.1.0');
      expect(cat.isDownloaded, isTrue);
      expect(merged.length, AnimalRepository.builtIns.length, reason: '同一隻不能出現兩次');
    });

    test('商店下載的動物（內建清單外）保留，且整份按名字排序', () {
      final merged = AnimalRepository.mergeBuiltIns(
        [a('zzz_bird', name: 'ㄚ鳥', downloaded: true), a('cat', name: '小花貓')],
        AnimalRepository.builtIns,
      );

      expect(merged.any((e) => e.animalId == 'zzz_bird'), isTrue);
      expect(merged.any((e) => e.animalId == 'cat'), isTrue);
      final names = merged.map((e) => e.displayName).toList();
      expect(names, [...names]..sort());
    });
  });

  group('缺席補算（app 關著的時候時間也要在走）', () {
    test('沒缺席就完全不變', () {
      expect(PetStats.hungerAfterAbsence(30, Duration.zero), 30);
    });

    test('關一小時 → 餓 60 點（1/60 每秒的節奏）', () {
      expect(PetStats.hungerAfterAbsence(0, const Duration(hours: 1)), closeTo(60, 0.01));
    });

    test('關很久也不會超過 maxHunger', () {
      expect(PetStats.hungerAfterAbsence(10, const Duration(days: 3)), PetStats.maxHunger);
    });

    test('系統時鐘被調回去（負的缺席時間）不會把飽食度扣成負數', () {
      expect(PetStats.hungerAfterAbsence(30, const Duration(hours: -5)), 30);
      expect(PetStats.hungerAfterAbsence(0, const Duration(hours: -5)), 0);
    });

    test('自訂速率照自己的速率算', () {
      expect(PetStats.hungerAfterAbsence(0, const Duration(seconds: 10), perSecond: 2), 20);
    });
  });

  group('餓度的存盤格式', () {
    test('新格式存进去取得回來，時間點也對', () {
      final at = DateTime.parse('2026-01-02 03:04:05.000');
      final decoded = SettingsRepository.decodeHunger(SettingsRepository.encodeHunger(42.5, at));

      expect(decoded?.hunger, 42.5);
      expect(decoded?.savedAt, at);
    });

    test('舊格式（裸小數）還讀得回來，且當作剛剛存的 —— 不追溯補算', () {
      final before = DateTime.now();
      final decoded = SettingsRepository.decodeHunger('42.00');

      expect(decoded?.hunger, 42);
      // 舊資料沒有時間戳，硬補會讓人在升級當下被一次餓透；這裡要等於「沒經過時間」
      expect(DateTime.now().difference(decoded!.savedAt), lessThan(const Duration(seconds: 5)));
      expect(before.isBefore(decoded.savedAt) || before == decoded.savedAt, isTrue);
    });

    test('讀不起來的內容回 null（呼叫端決定預設），不會亂給 0', () {
      expect(SettingsRepository.decodeHunger(null), isNull);
      expect(SettingsRepository.decodeHunger(''), isNull);
      expect(SettingsRepository.decodeHunger('abc'), isNull);
      expect(SettingsRepository.decodeHunger('{"at":123}'), isNull); // 沒有 hunger 欄位
    });
  });

  group('同一隻動物重新下載後不能繼續顯示舊圖', () {
    late Directory dir;
    late AnimalResource downloaded;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('dneko_loader');
      final json = {
        'animalId': 'fox',
        'displayName': '小狐狸',
        'frameWidth': 32,
        'frameHeight': 32,
        'actions': {
          'Sit': {'frames': ['sit1'], 'frameDurationMs': 250, 'loop': true},
        },
      };
      File('${dir.path}/animation.json').writeAsStringSync(jsonEncode(json));
      downloaded = AnimalResource(
        animalId: 'fox',
        displayName: '小狐狸',
        localFolderPath: dir.path,
        version: '1.0.0',
        isDownloaded: true,
        isBuiltIn: false,
        updatedAt: DateTime.parse('2026-01-01 00:00:00.000'),
      );
    });

    tearDown(() => dir.deleteSync(recursive: true));

    test('同一來源重複取會拿到同一個 provider（不要每幀重解碼）', () async {
      final loader = AnimationLoader();
      await loader.load(downloaded);

      expect(loader.getFrameImage(downloaded, 'sit1'),
          same(loader.getFrameImage(downloaded, 'sit1')));
    });

    test('換版重下載後，同一幀要拿到新的 provider（否則永遠顯示舊圖）', () async {
      final loader = AnimationLoader();
      await loader.load(downloaded);
      final before = loader.getFrameImage(downloaded, 'sit1');

      // 下載服務蓋寫同一個資料夾：路徑完全沒變，只有 version/updatedAt 變了
      final reDownloaded = downloaded.copyWith(version: '1.0.1');
      await loader.load(reDownloaded);

      expect(loader.getFrameImage(reDownloaded, 'sit1'), isNot(same(before)));
    });

    test('重複載入同一版不會把快取清掉（清錯就白解碼了）', () async {
      final loader = AnimationLoader();
      await loader.load(downloaded);
      final first = loader.getFrameImage(downloaded, 'sit1');

      await loader.load(downloaded);

      expect(loader.getFrameImage(downloaded, 'sit1'), same(first));
    });
  });
}
