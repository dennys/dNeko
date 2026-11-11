/// 寵物自主行為主迴圈的 tick 長度（16ms ≈ 60fps）
const Duration petTick = Duration(milliseconds: 16);

/// The animal used before the user picked one. Built-in ids live in AnimalRepository.builtIns.
const String defaultAnimalId = 'cat';

/// 可漫遊區域
enum PetZone {
  fullScreen, // 全螢幕
  bottomBand, // 只在螢幕下方一條（不擋視線）
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

/// 原生 overlay 視窗頂端被 WindowManager 夾在狀態列下方（dp）；
/// fallbackRoam 用同一個值，避免回退時頂端差一個狀態列（A-4b）。
const double defaultStatusBarHeightDp = 25;

/// 餵食時食物擲在牠旁邊多遠（預覽塊與 overlay 共用同一個距離，兩邊手感才一致）
const double feedDropDistance = 120;

/// 使用者可調的寵物設定（純資料 + 換算；I/O 在 SettingsRepository）
class PetSettings {
  static const double minSpeedPerSecond = 10;
  static const double maxSpeedPerSecond = 200;
  static const double defaultSpeedPerSecond = 90;

  static const double minPetSize = 80;
  static const double maxPetSize = 180; // 素材 212~256px，再放大会糊
  static const double defaultPetSize = 120;

  /// 餓的門檻（分鐘）：不餵的話多久後 isHungry 翻 true。
  /// 衰減速率固定 1 點/分鐘（PetStats.defaultHungerPerSecond），所以分鐘數＝門檻點數；
  /// 上限 100 = maxHunger，再大就永遠餓不到。
  static const int minHungerMinutes = 1;
  static const int maxHungerMinutes = 100;
  static const int defaultHungerMinutes = 60;

  /// 帶狀／角落區的邊長 = petSize × 此倍數
  static const double zoneSizeFactor = 2;

  final double speedPxPerSecond;

  /// 寵物視窗邊長（Flutter 邏輯像素 = dp）
  final double petSize;
  final PetZone zone;

  /// 目前選的動物（內建 id 或商店下載的 id）
  final String animalId;

  /// 介面語系；null = 跟隨系統（如 'en'、'zh'、'zh-TW'、'ja'）
  final String? languageCode;

  /// 外觀模式：'system' / 'light' / 'dark'
  final String themeMode;

  /// 餓的門檻（分鐘），見 [minHungerMinutes] / [maxHungerMinutes]
  final int hungerMinutesUntilHungry;

  /// 摸一下時是否發出叫聲（只對有提供音效的動物生效，見 animal_sound_catalog）
  final bool soundEnabled;

  const PetSettings({
    this.speedPxPerSecond = defaultSpeedPerSecond,
    this.petSize = defaultPetSize,
    this.zone = PetZone.fullScreen,
    this.animalId = defaultAnimalId,
    this.languageCode,
    this.themeMode = 'system',
    this.hungerMinutesUntilHungry = defaultHungerMinutes,
    this.soundEnabled = false,
  });

  /// languageCode 要能被明確設回 null（跟隨系統），所以用 sentinel 而不是 null 当「不變」
  static const _unchanged = Object();

  PetSettings copyWith({
    double? speedPxPerSecond,
    double? petSize,
    PetZone? zone,
    String? animalId,
    Object? languageCode = _unchanged,
    String? themeMode,
    int? hungerMinutesUntilHungry,
    bool? soundEnabled,
  }) =>
      PetSettings(
        speedPxPerSecond: speedPxPerSecond ?? this.speedPxPerSecond,
        petSize: petSize ?? this.petSize,
        zone: zone ?? this.zone,
        animalId: animalId ?? this.animalId,
        languageCode: languageCode == _unchanged
            ? this.languageCode
            : languageCode as String?,
        themeMode: themeMode ?? this.themeMode,
        hungerMinutesUntilHungry: hungerMinutesUntilHungry ?? this.hungerMinutesUntilHungry,
        soundEnabled: soundEnabled ?? this.soundEnabled,
      );

  /// 每幀該走幾像素（速度存 px/s，才不會被 tick 長度綁死）
  double get speedPerTick => speedPxPerSecond * petTick.inMilliseconds / 1000.0;

  Map<String, dynamic> toJson() => {
        'speedPxPerSecond': speedPxPerSecond,
        'petSize': petSize,
        'zone': zone.name,
        'animalId': animalId,
        'languageCode': languageCode,
        'themeMode': themeMode,
        'hungerMinutesUntilHungry': hungerMinutesUntilHungry,
        'soundEnabled': soundEnabled,
      };

  /// 容忍髒資料：缺欄位/型別不對/zone 不認識，一律回到預設值而不是丟例外
  factory PetSettings.fromJson(Map<String, dynamic> json) => PetSettings(
        speedPxPerSecond: _number(json['speedPxPerSecond'], defaultSpeedPerSecond)
            .clamp(minSpeedPerSecond, maxSpeedPerSecond)
            .toDouble(),
        petSize: _number(json['petSize'], defaultPetSize)
            .clamp(minPetSize, maxPetSize)
            .toDouble(),
        zone: PetZone.values.firstWhere(
          (z) => z.name == json['zone'],
          orElse: () => PetZone.fullScreen,
        ),
        animalId: json['animalId'] is String && (json['animalId'] as String).isNotEmpty
            ? json['animalId'] as String
            : defaultAnimalId,
        languageCode: json['languageCode'] is String && (json['languageCode'] as String).isNotEmpty
            ? json['languageCode'] as String
            : null,
        themeMode: const ['system', 'light', 'dark'].contains(json['themeMode'])
            ? json['themeMode'] as String
            : 'system',
        hungerMinutesUntilHungry: _number(json['hungerMinutesUntilHungry'], defaultHungerMinutes)
            .clamp(minHungerMinutes, maxHungerMinutes)
            .round(),
        soundEnabled: json['soundEnabled'] is bool ? json['soundEnabled'] as bool : false,
      );

  static num _number(Object? value, num fallback) =>
      value is num ? value : fallback;
}
