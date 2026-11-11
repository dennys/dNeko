import 'screen_metrics.dart';
import 'pet_settings.dart';

abstract interface class IOverlayService {
  Future<bool> hasPermission();
  Future<bool> requestPermission();

  /// 顯示 overlay 寵物（起點用 DB 裡上次存的位置）
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

  /// 關閉懸浮視窗。位置**不在這裡存**：主 app 只看得見視窗左上角，選單開著時那是選單的
  /// 位置（比寵物高一大截）。位置由 overlay 自己寫進 DB，[show] 讀它當 startPosition。
  Future<void> close();

  Future<bool> isActive();

  /// overlay → 主 app 的事件流（如選單按「結束」送來的 quit 指令）
  Stream<dynamic> get events;
}
