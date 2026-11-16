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

  /// 只在縮回寵物尺寸時用；拖曳一律開著。選單不再改這個視窗的尺寸（改成另一個視窗，
  /// 見 menu_main.dart 與原生 MenuOverlay.kt），所以這裡也不再需要「同時搬位置」。
  @override
  Future<void> resize({required double width, required double height}) =>
      FlutterOverlayWindow.resizeOverlay(width.toInt(), height.toInt(), true);

  @override
  Future<Offset> currentPosition() async {
    final p = await FlutterOverlayWindow.getOverlayPosition();
    return Offset(p.x, p.y);
  }

  @override
  Future<void> close() => FlutterOverlayWindow.closeOverlay();
}
