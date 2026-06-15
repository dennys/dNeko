import 'dart:ui';

/// 只負責：保存 Flutter 邏輯螢幕資訊，並提供寵物漫遊範圍
class ScreenMetrics {
  /// 邏輯像素的螢幕尺寸
  final Size logicalSize;

  /// 裝置像素密度（physical = logical * ratio）
  final double devicePixelRatio;

  const ScreenMetrics({
    required this.logicalSize,
    required this.devicePixelRatio,
  });

  /// 寵物可漫遊範圍（邏輯像素，視窗左上角座標範圍）
  /// [petLogicalSize] 寵物視窗邊長（邏輯像素）
  Rect roamingBounds(double petLogicalSize) => Rect.fromLTRB(
        0,
        0,
        (logicalSize.width - petLogicalSize).clamp(0, double.infinity),
        (logicalSize.height - petLogicalSize).clamp(0, double.infinity),
      );

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
