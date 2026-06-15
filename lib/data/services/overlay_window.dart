import 'dart:ui';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../../domain/i_overlay_window.dart';
import '../../domain/screen_metrics.dart';

/// 只負責：把邏輯座標換算成物理像素後操作 OS 視窗
class OverlayWindow implements IOverlayWindow {
  final ScreenMetrics _metrics;

  const OverlayWindow(this._metrics);

  @override
  Future<void> moveTo(Offset logicalPosition) {
    final p = _metrics.toPhysical(logicalPosition);
    return FlutterOverlayWindow.moveOverlay(OverlayPosition(p.dx, p.dy));
  }

  @override
  Future<void> resize({required double width, required double height}) =>
      FlutterOverlayWindow.resizeOverlay(
        _metrics.toPhysicalLength(width).toInt(),
        _metrics.toPhysicalLength(height).toInt(),
        false,
      );

  @override
  Future<void> close() => FlutterOverlayWindow.closeOverlay();
}