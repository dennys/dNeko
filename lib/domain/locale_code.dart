import 'dart:ui';

/// 把 'zh-TW' 這種語言碼拆成 Locale('zh', 'TW')。
///
/// 帶地區碼的單一語言碼（Locale('zh_TW')）會比對不到任何 arb，所以一定要拆。
/// 主 app（main.dart）與 overlay（overlay_main.dart）兩邊共用，加語系只改這一處。
Locale localeOfCode(String code) {
  final parts = code.split(RegExp('[-_]'));
  return parts.length > 1 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
}