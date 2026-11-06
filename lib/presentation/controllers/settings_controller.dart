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

  Future<void> update(PetSettings next) async {
    _settings = next;
    notifyListeners(); // 先更新 UI，存檔不卡畫面
    await _repository.save(next);
  }
}
