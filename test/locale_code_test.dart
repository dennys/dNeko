import 'dart:ui';
import 'package:dneko/domain/locale_code.dart';
import 'package:flutter_test/flutter_test.dart';

/// 語言碼 → Locale 的拆開（REVIEW #14）：主 app 與 overlay 兩邊共用同一個函式，
/// 加語系只改一處。帶地區碼的單一語言碼（Locale('zh_TW')）會比對不到任何 arb。
void main() {
  group('localeOfCode', () {
    test('單一語言碼', () {
      expect(localeOfCode('en'), const Locale('en'));
      expect(localeOfCode('ja'), const Locale('ja'));
    });

    test('語言-地區（連字號）', () {
      expect(localeOfCode('zh-TW'), const Locale('zh', 'TW'));
      expect(localeOfCode('zh-CN'), const Locale('zh', 'CN'));
    });

    test('語言_地區（底線也拆）', () {
      expect(localeOfCode('zh_TW'), const Locale('zh', 'TW'));
    });

    test('多段只取前兩段（Locale 只有 language + country）', () {
      expect(localeOfCode('zh-Hant-TW'), const Locale('zh', 'Hant'));
    });
  });
}