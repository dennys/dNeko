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

  /// 只在「視窗縮回寵物尺寸」時用，拖曳一律開著；要同時改 enableDrag 的地方走
  /// [moveAndResize]（開選單／收選單），所以這邊不暴露那個參數。
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

  /// 位置＋尺寸一次寫進視窗（單一 updateViewLayout）：切換選單時不會先搬後縮，中間不閃一幀。
  /// 不放進 IOverlayWindow，避免強迫其他實作（測試假物件）跟著改。
  Future<void> moveAndResize({
    required Offset position,
    required double width,
    required double height,
    required bool enableDrag,
  }) async {
    await FlutterOverlayWindow.updateOverlay(
      x: position.dx.round(),
      y: position.dy.round(),
      width: width.round(),
      height: height.round(),
      enableDrag: enableDrag,
    );
  }
}
