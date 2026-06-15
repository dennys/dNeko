import 'screen_metrics.dart';

abstract interface class IOverlayService {
  Future<bool> hasPermission();
  Future<bool> requestPermission();

  /// 顯示 overlay 寵物
  /// [languageCode] 目前 app 語系（如 "zh" / "en" / "ja"）
  Future<void> show({
    required String animalId,
    required ScreenMetrics metrics,
    required String languageCode,
  });

  Future<void> close();
  Future<bool> isActive();
}