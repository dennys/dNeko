import 'dart:convert';

import 'pet_behavior.dart';
import 'pet_stats.dart';

/// 開選單時送給「選單 isolate」的快照（JSON 過 MethodChannel）。
///
/// 選單那一側沒有 PetController、不讀 DB、也不做 l10n：它只把這一份快照畫出來，
/// 按到哪一格再把動作名稱送回寵物那側（見 `overlay_main._onMenuCommand`）。
/// 選單只活 6 秒，不必即時更新飽食度（餵食本來就會把選單關掉）。
class MenuPayload {
  const MenuPayload({
    required this.themeMode,
    required this.languageCode,
    required this.hunger,
    required this.hungryThreshold,
    required this.bondValue,
    required this.frozen,
    required this.labels,
  });

  /// 'light' / 'dark' / 其他 = 跟系統（跟主 app 同一個來源）
  final String themeMode;
  final String languageCode;
  final double hunger;
  final double hungryThreshold;
  final int bondValue;
  final bool frozen;

  /// 選單文字的來源：`feed` / `pet` / `freeze` / `close` / `quit`，加上 6 個
  /// `PetBehavior.name`。字串在寵物那側翻譯好才送過來 —— 選單 isolate 因此
  /// 不需要 DB、也不需要載入 arb。
  final Map<String, String> labels;

  String labelFor(String key) => labels[key] ?? key;

  factory MenuPayload.fromJson(Map<String, dynamic> json) {
    final rawLabels = json['labels'];
    return MenuPayload(
      themeMode: json['themeMode'] as String? ?? 'system',
      languageCode: json['languageCode'] as String? ?? 'en',
      // 跨 isolate 的數字在 JSON 裡 int/double 會互相竄（`20` 讀成 int），一律靠 num 收
      hunger: (json['hunger'] as num?)?.toDouble() ?? 0,
      hungryThreshold: (json['hungryThreshold'] as num?)?.toDouble() ??
          PetStats.defaultHungryThreshold,
      bondValue: (json['bondValue'] as num?)?.toInt() ?? 0,
      frozen: json['frozen'] as bool? ?? false,
      labels: rawLabels is Map
          ? rawLabels.map((k, v) => MapEntry('$k', '$v'))
          : const {},
    );
  }

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode,
        'languageCode': languageCode,
        'hunger': hunger,
        'hungryThreshold': hungryThreshold,
        'bondValue': bondValue,
        'frozen': frozen,
        'labels': labels,
      };

  String encode() => jsonEncode(toJson());

  static MenuPayload? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      return MenuPayload.fromJson(Map<String, dynamic>.from(map));
    } catch (_) {
      return null;
    }
  }
}

/// 選單的六個小動作格。**兩側共用的唯一清單**：選單 isolate 用它決定要畫幾格、按下去
/// 回傳的名字就是 `PetBehavior.name`，寵物那側（`overlay_main._flourishOf`）照同一份收。
/// 加減動作只改這裡 + `menu_main._iconFor` + l10n 六條，不會兩邊對不起來。
const List<PetBehavior> kFlourishBehaviors = [
  PetBehavior.lookAround,
  PetBehavior.doze,
  PetBehavior.wobble,
  PetBehavior.hop,
  PetBehavior.stretch,
  PetBehavior.circle,
];
