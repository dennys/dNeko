import 'screen_metrics.dart';
import 'pet_settings.dart';

abstract interface class IOverlayService {
  Future<bool> hasPermission();
  Future<bool> requestPermission();

  /// 顯示 overlay 寵物
  /// [languageCode] 目前 app 語系（如 "zh" / "en" / "ja"）
  Future<void> show({
    required String animalId,
    required PetSettings settings,
    required ScreenMetrics metrics,
    required String languageCode,
  });

  /// overlay 已經開著時，把新設定推過去（同一條 shareData 通道，不必重開視窗）
  Future<void> pushSettings({
    required String animalId,
    required PetSettings settings,
    required ScreenMetrics metrics,
    required String languageCode,
  });

  Future<void> close();
  Future<bool> isActive();
}
