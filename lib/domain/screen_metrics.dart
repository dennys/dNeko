import 'dart:ui';

/// 只負責：邏輯像素 ↔ 物理像素換算，並提供漫遊範圍
///
/// flutter_overlay_window 的 moveOverlay/resizeOverlay 在多數 Android
/// 版本使用「物理像素」，但 Flutter 內部繪圖用「邏輯像素」。
/// 本類別是唯一換算來源，避免單位混用。
class ScreenMetrics {
  /// 邏輯像素的螢幕尺寸
  final Size logicalSize;

  /// 裝置像素密度（physical = logical * ratio）
  final double devicePixelRatio;

  const ScreenMetrics({
    required this.logicalSize,
    required this.devicePixelRatio,
  });

  /// 物理像素的螢幕尺寸
  Size get physicalSize => Size(
        logicalSize.width * devicePixelRatio,
        logicalSize.height * devicePixelRatio,
      );

  /// 寵物可漫遊範圍（邏輯像素，視窗左上角座標範圍）
  /// [petLogicalSize] 寵物視窗邊長（邏輯像素）
  Rect roamingBounds(double petLogicalSize) => Rect.fromLTRB(
        0,
        0,
        (logicalSize.width - petLogicalSize).clamp(0, double.infinity),
        (logicalSize.height - petLogicalSize).clamp(0, double.infinity),
      );

  /// 邏輯座標 → 物理座標（給 moveOverlay 用）
  Offset toPhysical(Offset logical) => Offset(
        logical.dx * devicePixelRatio,
        logical.dy * devicePixelRatio,
      );

  /// 邏輯長度 → 物理長度（給 resizeOverlay 用）
  double toPhysicalLength(double logical) => logical * devicePixelRatio;

  Map<String, dynamic> toJson() => {
        'width': logicalSize.width,
        'height': logicalSize.height,
        'devicePixelRatio': devicePixelRatio,
      };

  factory ScreenMetrics.fromJson(Map<String, dynamic> json) => ScreenMetrics(
        logicalSize: Size(
          (json['width'] as num).toDouble(),
          (json['height'] as num).toDouble(),
        ),
        devicePixelRatio: (json['devicePixelRatio'] as num).toDouble(),
      );
}