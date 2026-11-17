import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../../domain/i_overlay_service.dart';
import '../../domain/screen_metrics.dart';
import '../../domain/pet_settings.dart';
import '../repositories/settings_repository.dart';

class OverlayService implements IOverlayService {
  static const _firstRunPosition = OverlayPosition(48, 96);

  OverlayService({SettingsRepository? positions})
      : _positions = positions ?? SettingsRepository();

  final SettingsRepository _positions;

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
    final start = await _startPosition(metrics, settings.petSize, animalId);

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
      startPosition: start,
    );

    unawaited(_shareStartupData(payload));
    // 選單是另一個視窗（原生 MenuOverlay.kt）：現在就把它那顆 engine 预热好，
    // 使用者第一次長按才不用等冷啟動。失敗不影響寵物（頂多選單慢一點）。
    unawaited(_menuNative('preWarmMenu'));
  }

  /// 呼叫 app 模組自己的原生端（`com.dneko/app`，MainActivity 註冊）。
  /// 綁不上（例：原生還沒這支）時靜默 —— 選單慢一點或 6 秒後自己關，都不能影響寵物。
  static const _appChannel = MethodChannel('com.dneko/app');

  Future<void> _menuNative(String method) async {
    try {
      await _appChannel.invokeMethod(method);
    } catch (_) {
      // 見上：這裡沒有值得崩潰的失敗
    }
  }

  /// 上次關閉時的位置，夾回目前螢幕內（螢幕轉向或換機後可能已經在畫面外）。
  /// 位置只能由 overlay 寫：主 app 只看得見視窗左上角，選單開著時那是選單的位置。
  Future<OverlayPosition> _startPosition(
      ScreenMetrics metrics, double petSize, String animalId) async {
    final Offset? saved;
    try {
      // 各養各的：每隻回到牠自己上次留下的位置
      saved = await _positions.loadPosition(animalId);
    } catch (_) {
      return _firstRunPosition;
    }
    if (saved == null) return _firstRunPosition;

    final clamped = metrics.clampPetPosition(saved, petSize);
    return OverlayPosition(clamped.dx, clamped.dy);
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

  /// 關閉懸浮。位置**不在這裡存**：主 app 只看得見視窗左上角，選單開著時那是選單的位置
  /// （比寵物高一大截），存下來下次開懸浮會偏高被系統夾到螢幕頂。位置由 overlay 自己存
  /// （`overlay_main._rememberPosition`）—— 只有它知道寵物在哪。
  @override
  Future<void> close() async {
    // 選單那顆視窗是自己 addView 出來的，關寵物不會順手關它；那顆 engine 更要主動放掉
    // —— 桌面寵物開一整天，不該在懸浮關了之後還佔著記憶體。
    await _menuNative('hideMenu');
    await _menuNative('disposeMenu');
    await FlutterOverlayWindow.closeOverlay();
  }

  @override
  Stream<dynamic> get events => FlutterOverlayWindow.overlayListener;

  @override
  Future<bool> isActive() => FlutterOverlayWindow.isActive();
}
