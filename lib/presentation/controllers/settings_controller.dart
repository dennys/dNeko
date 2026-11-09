import 'package:flutter/foundation.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/pet_settings.dart';

/// 只負責：協調設定頁面與 SettingsRepository（與 StoreController 同一個形狀）
class SettingsController extends ChangeNotifier {
  final SettingsRepository _repository;
  PetSettings _settings;

  PetSettings get settings => _settings;

  SettingsController({
    required this._repository,
    PetSettings? initial,
  }) : _settings = initial ?? const PetSettings();

  /// 只改記憶體並通知 UI（slider 拖動過程用這個，不要把 DB 寫入灌進每一個像素）
  void preview(PetSettings next) {
    _settings = next;
    notifyListeners();
  }

  /// 主頁顯示「存盤的那個餓度」用。走**主 app 自己的** DB 連線、不經過 overlay 的
  /// `_readOr`，所以「overlay 寫不寫得進去」與「overlay 讀不讀得回來」能分開判讀
  /// （DEVICE_TEST.md A-5）。回 null = 還不曾存過盤，不是 0。
  Future<HungerRecord?> loadPersistedHunger() => _repository.loadHunger();

  Future<void> update(PetSettings next) async {
    preview(next);
    await _repository.save(next);
  }
}
