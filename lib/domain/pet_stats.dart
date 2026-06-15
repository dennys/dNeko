import 'package:flutter/foundation.dart';

/// 寵物的數值狀態（飢餓值），與動畫、移動分離
class PetStats extends ChangeNotifier {
  static const double maxHunger = 100;

  double _hunger; // 0 = 飽足，100 = 非常餓
  double get hunger => _hunger;

  /// 是否餓到想找食物
  bool get isHungry => _hunger >= hungryThreshold;
  final double hungryThreshold;

  /// 每秒增加的飢餓值
  final double hungerPerSecond;

  PetStats({
    double initialHunger = 0,
    this.hungryThreshold = 60,
    this.hungerPerSecond = 1.0,
  }) : _hunger = initialHunger.clamp(0, maxHunger);

  /// 隨時間累積飢餓（由 controller 每幀呼叫）
  void tick(Duration elapsed) {
    final delta = hungerPerSecond * elapsed.inMilliseconds / 1000.0;
    _setHunger(_hunger + delta);
  }

  /// 進食後降低飢餓
  void feed({double amount = 40}) => _setHunger(_hunger - amount);

  void _setHunger(double value) {
    final clamped = value.clamp(0.0, maxHunger);
    if (clamped == _hunger) return;
    _hunger = clamped;
    notifyListeners();
  }
}