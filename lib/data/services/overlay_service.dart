import 'dart:async';
import 'dart:convert';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../../domain/i_overlay_service.dart';
import '../../domain/screen_metrics.dart';

class OverlayService implements IOverlayService {
  static const double collapsedSize = 120;
  static const int initialWindowSize = 320;

  @override
  Future<bool> hasPermission() => FlutterOverlayWindow.isPermissionGranted();

  @override
  Future<bool> requestPermission() async => (await FlutterOverlayWindow.requestPermission()) ?? false;

  @override
  Future<void> show({
    required String animalId,
    required ScreenMetrics metrics,
    required String languageCode,
  }) async {
    final payload = jsonEncode({
      'animalId': animalId,
      'petSize': collapsedSize,
      'languageCode': languageCode,
      'metrics': metrics.toJson(),
    });

    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      overlayTitle: 'dNeko',
      flag: OverlayFlag.defaultFlag,
      height: initialWindowSize,
      width: initialWindowSize,
      alignment: OverlayAlignment.topLeft,
      positionGravity: PositionGravity.none,
      startPosition: const OverlayPosition(48, 96),
    );

    unawaited(_shareStartupData(payload));
  }

  Future<void> _shareStartupData(String payload) async {
    const delays = [
      Duration.zero,
      Duration(milliseconds: 200),
      Duration(milliseconds: 500),
      Duration(seconds: 1),
    ];

    for (final delay in delays) {
      if (delay > Duration.zero) await Future.delayed(delay);
      try {
        await FlutterOverlayWindow.shareData(payload);
      } catch (_) {
        // 資料傳遞盡力即可，不能阻塞 OS overlay 視窗開啟。
      }
    }
  }

  @override
  Future<void> close() => FlutterOverlayWindow.closeOverlay();

  @override
  Future<bool> isActive() => FlutterOverlayWindow.isActive();
}
