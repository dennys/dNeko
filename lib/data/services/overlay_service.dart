import 'dart:convert';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../../domain/i_overlay_service.dart';
import '../../domain/screen_metrics.dart';

class OverlayService implements IOverlayService {
  static const double collapsedSize = 80;

  @override
  Future<bool> hasPermission() => FlutterOverlayWindow.isPermissionGranted();

  @override
  Future<bool> requestPermission() async =>
      (await FlutterOverlayWindow.requestPermission()) ?? false;

  @override
  Future<void> show({
    required String animalId,
    required ScreenMetrics metrics,
    required String languageCode,
  }) async {
    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      overlayTitle: 'dNeko',
      flag: OverlayFlag.defaultFlag,
      height: (collapsedSize * metrics.devicePixelRatio).toInt(),
      width: (collapsedSize * metrics.devicePixelRatio).toInt(),
      alignment: OverlayAlignment.topLeft,
      positionGravity: PositionGravity.none,
    );

    await FlutterOverlayWindow.shareData(jsonEncode({
      'animalId': animalId,
      'petSize': collapsedSize,
      'languageCode': languageCode,
      'metrics': metrics.toJson(),
    }));
  }

  @override
  Future<void> close() => FlutterOverlayWindow.closeOverlay();

  @override
  Future<bool> isActive() => FlutterOverlayWindow.isActive();
}