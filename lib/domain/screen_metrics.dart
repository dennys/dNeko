import 'dart:ui';

import 'pet_settings.dart';

/// 只負責：保存 Flutter 邏輯螢幕資訊，並提供寵物漫遊範圍
class ScreenMetrics {
  /// 邏輯像素的螢幕尺寸
  final Size logicalSize;

  /// 裝置像素密度；目前保留給 overlay isolate 了解來源螢幕資訊
  final double devicePixelRatio;

  /// 底部系統列（navigation bar）高度；下方區域要把它留出來
  final double bottomInset;

  const ScreenMetrics({
    required this.logicalSize,
    required this.devicePixelRatio,
    this.bottomInset = 0,
  });

  /// 寵物可漫遊範圍（邏輯像素，視窗左上角座標範圍）
  /// [petLogicalSize] 寵物視窗邊長（邏輯像素）
  Rect roamingBounds(double petLogicalSize) => Rect.fromLTRB(
        0,
        0,
        (logicalSize.width - petLogicalSize).clamp(0, double.infinity),
        (logicalSize.height - petLogicalSize).clamp(0, double.infinity),
      );

  /// 依區域設定算出可漫遊範圍（[petLogicalSize] 為寵物視窗邊長）。
  /// 全案只有這一處決定牠能去哪，邊緣行為/隨機目標/clamp 全部吃這個 Rect。
  Rect zoneBounds(double petLogicalSize, PetZone zone) {
    final full = roamingBounds(petLogicalSize);
    if (zone == PetZone.fullScreen) return full;

    // 可用最低點：扣掉底部系統列後再扣掉自身尺寸
    final bottom =
        (logicalSize.height - bottomInset - petLogicalSize).clamp(0.0, full.bottom).toDouble();

    if (zone == PetZone.bottomBand) {
      final thickness = petLogicalSize * PetSettings.zoneSizeFactor;
      return Rect.fromLTRB(
        full.left,
        (bottom - thickness).clamp(0.0, bottom).toDouble(),
        full.right,
        bottom,
      );
    }

    final side = petLogicalSize * PetSettings.zoneSizeFactor;
    final w = side.clamp(0.0, full.width).toDouble();
    final topH = side.clamp(0.0, full.height).toDouble();
    final bottomH = side.clamp(0.0, bottom).toDouble();
    return switch (zone) {
      PetZone.topLeft => Rect.fromLTWH(full.left, full.top, w, topH),
      PetZone.topRight => Rect.fromLTWH(full.right - w, full.top, w, topH),
      PetZone.bottomLeft => Rect.fromLTWH(full.left, bottom - bottomH, w, bottomH),
      PetZone.bottomRight => Rect.fromLTWH(full.right - w, bottom - bottomH, w, bottomH),
      _ => full,
    };
  }

  Map<String, dynamic> toJson() => {
        'width': logicalSize.width,
        'height': logicalSize.height,
        'devicePixelRatio': devicePixelRatio,
        'bottomInset': bottomInset,
      };

  factory ScreenMetrics.fromJson(Map<String, dynamic> json) => ScreenMetrics(
        logicalSize: Size(
          (json['width'] as num).toDouble(),
          (json['height'] as num).toDouble(),
        ),
        devicePixelRatio: (json['devicePixelRatio'] as num).toDouble(),
        bottomInset: (json['bottomInset'] as num?)?.toDouble() ?? 0,
      );
}
