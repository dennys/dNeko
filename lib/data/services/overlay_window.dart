import 'dart:ui';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../../domain/i_overlay_window.dart';

/// 只負責：把 app 邏輯座標傳給 OS 視窗
class OverlayWindow implements IOverlayWindow {
  const OverlayWindow();

  @override
  Future<void> moveTo(Offset logicalPosition) {
    return FlutterOverlayWindow.moveOverlay(
      OverlayPosition(logicalPosition.dx, logicalPosition.dy),
    );
  }

  @override
  Future<void> resize({required double width, required double height, bool enableDrag = true}) =>
      FlutterOverlayWindow.resizeOverlay(
        width.toInt(),
        height.toInt(),
        enableDrag,
      );

  @override
  Future<Offset> currentPosition() async {
    final p = await FlutterOverlayWindow.getOverlayPosition();
    return Offset(p.x, p.y);
  }

  @override
  Future<void> close() => FlutterOverlayWindow.closeOverlay();
}
