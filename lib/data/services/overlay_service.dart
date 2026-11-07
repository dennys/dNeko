import 'dart:async';
import 'dart:convert';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../../domain/i_overlay_service.dart';
import '../../domain/screen_metrics.dart';
import '../../domain/pet_settings.dart';

class OverlayService implements IOverlayService {
  static const double collapsedSize = PetSettings.defaultPetSize;

  @override
  Future<bool> hasPermission() => FlutterOverlayWindow.isPermissionGranted();

  @override
  Future<bool> requestPermission() async => (await FlutterOverlayWindow.requestPermission()) ?? false;

  @override
  Future<void> show({
    required String animalId,
    required PetSettings settings,
    required ScreenMetrics metrics,
    required String languageCode,
  }) async {
    final payload = _payload(animalId, settings, metrics, languageCode);

    await FlutterOverlayWindow.showOverlay(
      // 原生拖曳（插件 onTouch 用 rawX/rawY）。拖曳期間由 OverlayPetDriver 暫停、
      // overlay_main 輪詢 getOverlayPosition 同步座標，放開後再恢復自主移動。
      enableDrag: true,
      overlayTitle: 'dNeko',
      flag: OverlayFlag.defaultFlag,
      height: settings.petSize.toInt(),
      width: settings.petSize.toInt(),
      alignment: OverlayAlignment.topLeft,
      positionGravity: PositionGravity.none,
      startPosition: const OverlayPosition(48, 96),
    );

    unawaited(_shareStartupData(payload));
  }

  @override
  Future<void> pushSettings({
    required String animalId,
    required PetSettings settings,
    required ScreenMetrics metrics,
    required String languageCode,
  }) async {
    // 視窗已在跑，送一次就夠（不需要 showOverlay 那套延遲重送）
    await FlutterOverlayWindow.shareData(_payload(animalId, settings, metrics, languageCode));
  }

  String _payload(
    String animalId,
    PetSettings settings,
    ScreenMetrics metrics,
    String languageCode,
  ) =>
      jsonEncode({
        'animalId': animalId,
        'settings': settings.toJson(),
        'languageCode': languageCode,
        'metrics': metrics.toJson(),
      });

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
  Stream<dynamic> get events => FlutterOverlayWindow.overlayListener;

  @override
  Future<bool> isActive() => FlutterOverlayWindow.isActive();
}
