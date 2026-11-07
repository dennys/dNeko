/// 寵物自主行為主迴圈的 tick 長度（16ms ≈ 60fps）
const Duration petTick = Duration(milliseconds: 16);

/// 目前唯一內建的動物（商店下載的東西以後由 DB 決定）
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

/// 使用者可調的寵物設定（純資料 + 換算；I/O 在 SettingsRepository）
class PetSettings {
  static const double minSpeedPerSecond = 10;
  static const double maxSpeedPerSecond = 200;
  static const double defaultSpeedPerSecond = 90;

  static const double minPetSize = 80;
  static const double maxPetSize = 180; // 素材 212~256px，再放大会糊
  static const double defaultPetSize = 120;

  /// 帶狀／角落區的邊長 = petSize × 此倍數
  static const double zoneSizeFactor = 2;

  final double speedPxPerSecond;

  /// 寵物視窗邊長（Flutter 邏輯像素 = dp）
  final double petSize;
  final PetZone zone;

  /// 目前選的動物（內建 id 或商店下載的 id）
  final String animalId;

  const PetSettings({
    this.speedPxPerSecond = defaultSpeedPerSecond,
    this.petSize = defaultPetSize,
    this.zone = PetZone.fullScreen,
    this.animalId = defaultAnimalId,
  });

  /// 每幀該走幾像素（速度存 px/s，才不會被 tick 長度綁死）
  double get speedPerTick => speedPxPerSecond * petTick.inMilliseconds / 1000.0;

  Map<String, dynamic> toJson() => {
        'speedPxPerSecond': speedPxPerSecond,
        'petSize': petSize,
        'zone': zone.name,
        'animalId': animalId,
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
      );

  static double _number(Object? value, double fallback) =>
      value is num ? value.toDouble() : fallback;
}
