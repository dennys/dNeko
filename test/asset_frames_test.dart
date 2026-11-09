import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dneko/data/models/animation_definition.dart';
import 'package:dneko/data/repositories/animal_repository.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 素材檔的守門員（對應 `ASSET_PROMPT.md` 第 6 節的 self-check 清單）。
///
/// 為什麼要有這一支：圖片模型產的幀最常壞在「看得出來但人眼會漏」的地方 ——
/// 背景其實是白底不是透明、兩幀其實是同一張、`animation.json` 參考了不存在的檔名、
/// 主體貼邊被裁。在 app 裡的症狀分别是「pet 掛著白方塊 / 逐幀動畫變靜止 /
/// 整個變成佔位圓」，而這些用看的很難發現。
///
/// 分級原則：**會讓 app 壞掉或明顯錯誤的 → fail**；**風格與尺寸建議 → 只 print 示警**。
/// （貓的素材画布本來就不齊，硬性規定會把整個檢查器變成永遠紅的，然後被人關掉。）
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const animalsDir = 'assets/animals';
  const requiredActions = ['WalkUp', 'WalkDown', 'WalkSide', 'Sit', 'Sleep', 'Eat', 'Affectionate'];

  List<Directory> animalFolders() {
    if (!Directory(animalsDir).existsSync()) return const [];
    return Directory(animalsDir)
        .listSync()
        .whereType<Directory>()
        .where((d) => File('${d.path}/animation.json').existsSync() && _pngsIn(d).isNotEmpty)
        .toList();
  }

  group('檢查器本身要抓得到問題（不是怎麼跑都過的假測試）', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('asset_check'));
    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('背景不透明 → 擋', () async {
      File('${dir.path}/sit1.png').writeAsBytesSync(await _opaquePng());

      final issues = await _checkFrames(dir);
      expect(issues.any((i) => i.contains('背景不透明')), isTrue, reason: '$issues');
    });

    test('背景透明 + 主體置中 → 放過（確認不是無腦全擋）', () async {
      File('${dir.path}/sit1.png').writeAsBytesSync(await _transparentPngWithBlob());

      expect(await _checkFrames(dir), isEmpty);
    });

    test('兩幀內容完全相同 → 擋（模型偷懶複製同一張是最常見的失敗）', () async {
      final good = await _transparentPngWithBlob();
      File('${dir.path}/sit1.png').writeAsBytesSync(good);
      File('${dir.path}/sit2.png').writeAsBytesSync(good);

      final issues = await _checkFrames(dir);
      expect(issues.any((i) => i.contains('完全相同')), isTrue, reason: '$issues');
    });

    test('主體貼到畫布邊緣 → 擋（會被裁切）', () async {
      File('${dir.path}/sit1.png').writeAsBytesSync(await _blobPng(touchingEdge: true));

      final issues = await _checkFrames(dir);
      expect(issues.any((i) => i.contains('貼到畫布邊緣')), isTrue, reason: '$issues');
    });
  });

  group('assets/animals 的真實素材', () {
    test('只有 animation.json、還沒有圖的資料夾不准註冊進選單', () {
      // 「選單選得到、點下去畫不出來」是最難看的一種壞（小柴犬就卡在這裡過：
      // assets/animals/dog/ 只有 animation.json，12 張圖全缺）。
      // 素材還沒產可以留著佔位，但不能進 AnimalRepository.builtIns。
      if (!Directory(animalsDir).existsSync()) return;
      for (final dir in Directory(animalsDir).listSync().whereType<Directory>()) {
        if (!File('${dir.path}/animation.json').existsSync()) continue;
        if (_pngsIn(dir).isNotEmpty) continue;
        final id = p.basename(dir.path);
        expect(AnimalRepository.builtIn(id), isNull,
            reason: '$id 一張圖都沒有卻註冊進 builtIns → 主頁選得到、overlay 只能畫佔位圓');
        debugPrint('[warn] $id 只有 animation.json（素材待產，產圖流程見 ASSET_PROMPT.md）');
      }
    });

    test('每一隻都有 animation.json 且能通過模型層驗證', () {
      final folders = animalFolders();
      expect(folders, isNotEmpty, reason: '$animalsDir 下一隻動物都沒有');

      for (final dir in folders) {
        final decoded = jsonDecode(File('${dir.path}/animation.json').readAsStringSync());
        expect(decoded, isA<Map<String, dynamic>>(), reason: '${dir.path}/animation.json 不是物件');
        expect(
          () => AnimalAnimationDefinition.fromJson(Map<String, dynamic>.from(decoded as Map)),
          returnsNormally,
          reason: '${dir.path}/animation.json 驗證不過 → app 會整隻載入失敗',
        );
      }
    });

    test('六個動作都要齊，而且參考到的幀檔真的存在', () {
      for (final dir in animalFolders()) {
        final raw = _readJson(dir);
        final actions = raw['actions'] as Map;

        for (final action in requiredActions) {
          expect(actions.containsKey(action), isTrue, reason: '${dir.path} 缺動作 $action');
          for (final frame in (actions[action] as Map)['frames'] as List) {
            expect(File('${dir.path}/$frame.png').existsSync(), isTrue,
                reason: '${dir.path}/animation.json 參考了 $frame.png，但檔案不存在 → 播放時這一幀是空的');
          }
        }

        // 認不出的鍵不會讓 app 壞掉（模型層跳過），但通常代表鍵名打錯
        final unknown = actions.keys.where((k) => !requiredActions.contains(k)).toList();
        if (unknown.isNotEmpty) debugPrint('[warn] ${dir.path} 有 app 不認識的動作鍵（會被跳過）：$unknown');
      }
    });

    test('沒有孤兒圖（有檔但没人參考 = 白打包進 APK），也沒有缺檔', () {
      for (final dir in animalFolders()) {
        final raw = _readJson(dir);
        final used = <String>{
          for (final action in (raw['actions'] as Map).values)
            for (final frame in (action as Map)['frames'] as List) '$frame.png',
        };
        final onDisk = dir
            .listSync()
            .whereType<File>()
             .map((f) => p.basename(f.path))
            .where((n) => n.endsWith('.png'))
            .toSet();

        expect(onDisk.difference(used), isEmpty, reason: '${dir.path} 這些圖沒被任何動作用到');
        expect(used.difference(onDisk), isEmpty, reason: '${dir.path} animation.json 參考了不存在的檔案');
      }
    });

    test('每張圖都要：合法 PNG、有 alpha、背景真的透明、不被裁切、幀與幀之間不是同一張', () async {
      for (final dir in animalFolders()) {
        final issues = await _checkFrames(dir);
        expect(issues, isEmpty, reason: '${dir.path} 素材不合格：\n  - ${issues.join('\n  - ')}');
      }
    });

    test('画布不齊 / frameWidth 寫錯只示警（貓的素材本來就這樣，不能因此擋掉整個檢查）', () async {
      for (final dir in animalFolders()) {
        final pngs = _pngsIn(dir);
        if (pngs.isEmpty) continue;

        final sizes = pngs.map((f) => _pngHeader(f.readAsBytesSync())).toSet();
        if (sizes.length > 1) {
          debugPrint('[warn] ${dir.path} 各幀画布尺寸不一致 —— 播放時會抖/飄，重生成時請固定同一尺寸：'
              '${sizes.map((s) => '${s.width}x${s.height}').toList()}');
        }

        final raw = _readJson(dir);
        final declared = '${raw['frameWidth']}x${raw['frameHeight']}';
        final actual = sizes.map((s) => '${s.width}x${s.height}').toSet();
        if (!actual.contains(declared)) {
          debugPrint('[warn] ${dir.path} animation.json 的 frameWidth/frameHeight=$declared，'
              '實際圖是 $actual（目前只在沒傳 displayWidth 時當備援尺寸，但還是該寫對）');
        }
      }
    });

    test('�D�ίʵe�V�����@�˴ؤo�A�}�u�u���b�P�@�u�s�]�_�h���ʮɷ|���B�ů��^', () async {
      for (final dir in animalFolders()) {
        final frames = _pngsIn(dir).where((f) => !f.path.contains('sleep')).toList();
        if (frames.isEmpty) continue;

        final sizes = frames.map((f) => _pngHeader(f.readAsBytesSync())).map((h) => '${h.width}x${h.height}').toSet();
        expect(sizes.length, 1, reason: '${dir.path} �D�ίʵe�ؤo���P�G$sizes');

        final feet = <int>[];
        for (final f in frames) {
          final px = await _decode(f.readAsBytesSync());
          final box = px == null ? null : _alphaBoundingBox(px);
          if (box != null) feet.add(box.bottom);
        }
        final spread = feet.reduce((a, b) => a > b ? a : b) - feet.reduce((a, b) => a < b ? a : b);
        expect(spread, lessThanOrEqualTo(2), reason: '${dir.path} �}�u�u���P�V��t $spread px�G$feet');
      }
    });
  });
}

Map<String, dynamic> _readJson(Directory dir) =>
    Map<String, dynamic>.from(jsonDecode(File('${dir.path}/animation.json').readAsStringSync()) as Map);

List<File> _pngsIn(Directory dir) =>
    (dir.listSync().whereType<File>().where((f) => f.path.endsWith('.png')).toList())
      ..sort((a, b) => a.path.compareTo(b.path));

/// 單張圖的硬性檢查；回傳「一定要修」的問題清單（空 = 通過）。
Future<List<String>> _checkFrames(Directory dir) async {
  final issues = <String>[];
  final byName = <String, Uint8List>{};

  for (final file in _pngsIn(dir)) {
    final name = p.basename(file.path);
    final bytes = file.readAsBytesSync();
    byName[name] = bytes;

    if (!_isPng(bytes)) {
      issues.add('$name 不是合法的 PNG');
      continue;
    }
    final header = _pngHeader(bytes);
    if (!header.hasAlpha) {
      issues.add('$name 沒有 8-bit alpha 通道（colorType=${header.colorType}）→ overlay 上會是實心方塊');
      continue;
    }

    final px = await _decode(bytes);
    if (px == null) {
      issues.add('$name 解碼失敗');
      continue;
    }

    int alphaAt(int x, int y) => px.bytes.getUint8((y * px.width + x) * 4 + 3);

    // 四角全不透明 → 十之八九是背景根本沒摳掉（模型很愛給白底）
    if (alphaAt(0, 0) > 250 &&
        alphaAt(px.width - 1, 0) > 250 &&
        alphaAt(0, px.height - 1) > 250 &&
        alphaAt(px.width - 1, px.height - 1) > 250) {
      issues.add('$name 背景不透明（四角 alpha 都是 255）→ 桌寵會掛著一個方塊');
    }

    final box = _alphaBoundingBox(px);
    if (box == null) {
      issues.add('$name 全透明（裡面什麼都沒有）');
    } else if (box.left == 0 || box.top == 0 || box.right == px.width || box.bottom == px.height) {
      issues.add('$name 主體貼到畫布邊緣（$box / ${px.width}x${px.height}）→ 會被裁掉');
    }
  }

  final names = byName.keys.toList();
  for (var i = 0; i < names.length; i++) {
    for (var j = i + 1; j < names.length; j++) {
      if (_bytesEqual(byName[names[i]]!, byName[names[j]]!)) {
        issues.add('${names[i]} 與 ${names[j]} 完全相同（逐幀動畫會變靜止）');
      }
    }
  }
  return issues;
}

class _PngHeader {
  const _PngHeader(this.width, this.height, this.bitDepth, this.colorType);
  final int width;
  final int height;
  final int bitDepth;
  final int colorType; // 0 灰 / 2 RGB / 3 調色盤 / 4 灰+alpha / 6 RGBA

  bool get hasAlpha => bitDepth == 8 && (colorType == 6 || colorType == 4);

  // 沒有覆寫 == 的話 toSet() 比的是物件实例，13 張同尺寸的圖也會被當成「13 種尺寸」
  @override
  bool operator ==(Object other) =>
      other is _PngHeader &&
      other.width == width &&
      other.height == height &&
      other.bitDepth == bitDepth &&
      other.colorType == colorType;

  @override
  int get hashCode => Object.hash(width, height, bitDepth, colorType);
}

_PngHeader _pngHeader(Uint8List b) {
  final view = ByteData.sublistView(b);
  // 8 簽名 + 4 length + 4 "IHDR" 之後才是 width / height / bitDepth / colorType
  return _PngHeader(view.getUint32(16), view.getUint32(20), b[24], b[25]);
}

bool _isPng(Uint8List b) =>
    b.length > 8 &&
    b[0] == 0x89 &&
    b[1] == 0x50 &&
    b[2] == 0x4E &&
    b[3] == 0x47 &&
    b[4] == 0x0D &&
    b[5] == 0x0A &&
    b[6] == 0x1A &&
    b[7] == 0x0A;

class _Decoded {
  const _Decoded(this.width, this.height, this.bytes);
  final int width;
  final int height;
  final ByteData bytes; // rawStraightRgba
}

/// 用 Flutter 自己的解碼器，不另外拉 image 套件當 dependency。
Future<_Decoded?> _decode(Uint8List bytes) async {
  try {
    final image = await _decodeToImage(bytes);
    final w = image.width, h = image.height;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    image.dispose();
    return data == null ? null : _Decoded(w, h, data);
  } catch (_) {
    return null;
  }
}

Future<ui.Image> _decodeToImage(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}

/// 產生測試用 PNG（交給 Flutter 編碼，省掉自己寫 zlib + filter）。
Future<Uint8List> _pngFromRgba(int w, int h, int Function(int x, int y) rgba) async {
  final pixels = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final value = rgba(x, y);
      final o = (y * w + x) * 4;
      pixels[o] = (value >> 24) & 0xFF;
      pixels[o + 1] = (value >> 16) & 0xFF;
      pixels[o + 2] = (value >> 8) & 0xFF;
      pixels[o + 3] = value & 0xFF;
    }
  }
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(pixels, w, h, ui.PixelFormat.rgba8888, completer.complete);
  final image = await completer.future;
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// 全不透明（背景沒摳掉的樣子）
Future<Uint8List> _opaquePng() => _pngFromRgba(8, 8, (x, y) => 0xC8783CFF);

/// 透明背景 + 中間一塊主體（合格素材的樣子）
Future<Uint8List> _transparentPngWithBlob() => _pngFromRgba(8, 8, (x, y) {
      final inside = x >= 2 && x <= 5 && y >= 2 && y <= 5;
      return inside ? 0xC8783CFF : 0x00000000;
    });

/// 主體貼到右邊緣（會從右邊被裁）
Future<Uint8List> _blobPng({required bool touchingEdge}) => _pngFromRgba(8, 8, (x, y) {
      final right = touchingEdge ? 7 : 6;
      final inside = x >= 2 && x <= right && y >= 2 && y <= 5;
      return inside ? 0xC8783CFF : 0x00000000;
    });

/// 有.alpha 像素的外框；全透明回 null。
_BoundingBox? _alphaBoundingBox(_Decoded px) {
  const threshold = 8;
  var minX = px.width, minY = px.height, maxX = -1, maxY = -1;
  for (var y = 0; y < px.height; y++) {
    for (var x = 0; x < px.width; x++) {
      if (px.bytes.getUint8((y * px.width + x) * 4 + 3) <= threshold) continue;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }
  if (maxX < 0) return null;
  return _BoundingBox(minX, minY, maxX + 1, maxY + 1);
}

class _BoundingBox {
  const _BoundingBox(this.left, this.top, this.right, this.bottom);
  final int left, top, right, bottom;
  @override
  String toString() => 'x$left..$right y$top..$bottom';
}

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
