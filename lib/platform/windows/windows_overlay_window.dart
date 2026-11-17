import 'dart:ui';

import 'package:window_manager/window_manager.dart';

import '../../domain/i_overlay_window.dart';

/// Windows 版的 [IOverlayWindow]：app 自己那顆 frameless 視窗就是寵物。
///
/// Android 那边「視窗不在時插件只回 false」的機制在這裡不存在（Windows 沒有 service
/// 被關掉這回事），所以四個方法一律回傳 true。偵測「懸浮已被關掉」在 Windows 走
/// 系統匣的「隱藏／結束」，由 [WindowsPetApp] 直接處理，不靠 [OverlayPetDriver] 的
/// 連續拒絕判定。
class WindowsOverlayWindow implements IOverlayWindow {
  const WindowsOverlayWindow();

  @override
  Future<bool> moveTo(Offset position) async {
    await windowManager.setPosition(position, animate: false);
    return true;
  }

  @override
  Future<bool> resize({required double width, required double height}) async {
    await windowManager.setSize(Size(width, height), animate: false);
    return true;
  }

  @override
  Future<Offset> currentPosition() => windowManager.getPosition();

  /// 關閉 = 藏起來（桌寵沒有「關掉但程式還在」那種中間態；真的離開走系統匣「結束」）
  @override
  Future<void> close() => windowManager.hide();

  /// 系統匣用的「顯示」
  Future<void> show() => windowManager.show();
}
