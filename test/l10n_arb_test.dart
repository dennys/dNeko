import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 選單的文字是寵物那側翻好後經 `MenuPayload.labels` 送過去的 —— 選單 isolate 自己不讀 arb、
/// 不做翻譯。所以**少一個鍵不會崩潰**，只會把 `menuFeedUnfreezes` 這種原始鍵名直接畫給
/// 使用者看，而且只有那個語系的人才看得見（最容易漏的一種 bug）。四語系的鍵目前靠人工對齊，
/// 就用測試擋住。
const _arbs = ['app_en', 'app_ja', 'app_zh', 'app_zh_TW'];

/// 選單真的會用到的鍵：`overlay_main._menuPayload` 的 labels 全部來自這裡，
/// 六個動作格的鍵對應 `kFlourishBehaviors`（加減動作要連這裡一起改，AGENTS.md 有記）。
const _menuKeys = [
  'menuFeed',
  'menuPet',
  'menuFreeze',
  'menuUnfreeze',
  'menuClose',
  'menuQuit',
  'menuFeedUnfreezes',
  'menuActionLookAround',
  'menuActionDoze',
  'menuActionWobble',
  'menuActionHop',
  'menuActionStretch',
  'menuActionCircle',
];

String _path(String name) => 'lib/l10n/$name.arb';

Map<String, dynamic> _read(String name) =>
    jsonDecode(File(_path(name)).readAsStringSync()) as Map<String, dynamic>;

/// 模板裡的佔位符 `{count}` 之類 —— 少一個就會在產生後呼叫時丟 FormatException
Set<String> _placeholders(Map<String, dynamic> map, String key) =>
    (map[key] is String)
        ? RegExp(r'\{\s*(\w+)').allMatches(map[key] as String).map((m) => m.group(1)!).toSet()
        : <String>{};

void main() {
  group('arb 四語系一致性', () {
    test('四個檔案都在', () {
      for (final n in _arbs) {
        expect(File(_path(n)).existsSync(), isTrue, reason: '缺 ${_path(n)}');
      }
    });

    test('鍵集合與 en 完全相同（不缺、不多）', () {
      final base = _read('app_en').keys.where((k) => !k.startsWith('@')).toSet();
      expect(base, isNotEmpty, reason: '解析不出鍵代表 arb 讀錯/格式壞了');
      for (final n in _arbs) {
        final keys = _read(n).keys.where((k) => !k.startsWith('@')).toSet();
        expect(keys.difference(base), isEmpty, reason: '$n 有 en 沒有的鍵：${keys.difference(base)}');
        expect(base.difference(keys), isEmpty, reason: '$n 缺鍵：${base.difference(keys)}');
      }
    });

    test('選單會用到的鍵每個語系都翻好了', () {
      for (final n in _arbs) {
        final map = _read(n);
        for (final k in _menuKeys) {
          final v = map[k];
          expect(v, isA<String>(), reason: '$n 缺 $k（選單會把鍵名畫出來）');
          final text = (v as String).trim();
          expect(text, isNotEmpty, reason: '$n 的 $k 是空字串');
          expect(text, isNot(k), reason: '$n 的 $k 還沒翻（值等於鍵名）');
        }
      }
    });

    test('佔位符各語系要一致（少一個會在執行期 FormatException）', () {
      final en = _read('app_en');
      for (final key in en.keys.where((k) => !k.startsWith('@'))) {
        final expected = _placeholders(en, key);
        if (expected.isEmpty) continue;
        for (final n in _arbs) {
          expect(_placeholders(_read(n), key), expected,
              reason: '$n 的 $key 佔位符與 en 對不起來：$expected');
        }
      }
    });
  });
}
