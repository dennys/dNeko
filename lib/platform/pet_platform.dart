import 'dart:io' show Platform;

/// 平台差異的**唯一**開關。
///
/// 散在 UI 裡的 `Platform.isWindows` 遲早會各寫一份、然後有一條路先爛掉，所以入口分岔
/// （桌寵 shell vs 主 app 設定頁）與 DB 後端切換都認這一個。要支援第二個桌面平台（Linux）
/// 就在這裡加，不要在呼叫端加 `Platform.isLinux`。
class PetPlatform {
  const PetPlatform({required this.isWindowsPet});

  /// Android：主 app 是設定頁，寵物跑在插件的懸浮視窗 + 獨立 isolate，選單是**第二顆**視窗
  /// （`FlutterTextureView` resize 會拉伸舊幀，只能另開 —— 見 AGENTS.md）。
  static const PetPlatform android = PetPlatform(isWindowsPet: false);

  /// Windows：整個 app 就是那顆懸浮視窗（frameless + 透明 + 置頂 + 不搶焦點），
  /// 選單疊在同一顆視窗裡，沒有 overlay 插件、沒有第二顆 engine、沒有 isolate。
  static const PetPlatform windows = PetPlatform(isWindowsPet: true);

  /// 目前跑在哪（Windows 走桌寵 shell，其他走 Android 那套）。
  static PetPlatform get current => Platform.isWindows ? windows : android;

  final bool isWindowsPet;
}
