import 'package:flutter/foundation.dart';

/// 寵物的數值狀態（飢餓值），與動畫、移動分離。
class PetStats extends ChangeNotifier {
  static const double maxHunger = 100;

  /// 餓到想找食物的門檻
  static const double defaultHungryThreshold = 60;

  /// 每秒累積的飢餓值。1/60 ≈ 每分鐘 1 點：不餵的話約 1 小時變餓、約 100 分鐘餓透。
  ///
  /// 舊值是 1.0/秒 —— 那代表開機 **100 秒**就永遠停在 maxHunger，而餵食只贖回 40，
  /// 於是跑兩分鐘後 `isHungry` 恆為 true，PetBrain 永遠只選 wander/idle，
  /// 這隻寵物再也沒睡過覺。
  static const double defaultHungerPerSecond = 1 / 60;

  /// 「多久變餓」（分鐘）換成門檻點數。預設速率 1 點/分鐘下兩者數值相等；
  /// 帶 perSecond 參數是為了速率若改動時換算不會悄悄錯掉。
  static double hungryThresholdForMinutes(num minutes, {double perSecond = defaultHungerPerSecond}) =>
      minutes * 60 * perSecond;

  /// 會通知 UI 的最小變化量。
  ///
  /// 主迴圈是 16ms 一跳，每跳只加約 0.016 點；每個跳動都 notifyListeners() 的話，
  /// 懸浮視窗那側就固定 60 次/秒重建 widget —— 桌寵最不該做的事就是空轉。
  /// 1 點的解析度對一根進度條已經足夠。
  static const double _notifyGranularity = 1.0;

  double _hunger; // 0 = 飽足，100 = 非常餓
  double get hunger => _hunger;

  double _lastNotified;

  /// 是否餓到想找食物
  bool get isHungry => _hunger >= hungryThreshold;

  /// 餓的門檻（點數）。改動要走 [setHungryThreshold]（要通知 isHungry 翻轉）
  double hungryThreshold;

  /// 改門檻（設定頁即時生效）；只有 isHungry 狀態翻轉才通知（PetBrain 與進度條顏色都看它）
  void setHungryThreshold(double value) {
    if (value == hungryThreshold) return;
    final wasHungry = _hunger >= hungryThreshold;
    hungryThreshold = value;
    if ((_hunger >= value) != wasHungry) notifyListeners();
  }

  /// 每秒增加的飢餓值
  final double hungerPerSecond;

  PetStats({
    double initialHunger = 0,
    this.hungryThreshold = defaultHungryThreshold,
    this.hungerPerSecond = defaultHungerPerSecond,
  })  : _hunger = initialHunger.clamp(0.0, maxHunger),
        _lastNotified = initialHunger.clamp(0.0, maxHunger);

  /// 缺席期間該補上的飢餓值：懸浮視窗沒開時沒有人呼叫 [tick]，但時間照樣在走。
  ///
  /// 純函式、可單測（呼叫端自己算「距上次存盤多久」傳進來）。
  /// 時間為負（使用者改過系統時鐘）就當作沒經過 —— 不會把飽食度倒扣成負的。
  static double hungerAfterAbsence(double hunger, Duration absent, {double perSecond = defaultHungerPerSecond}) {
    if (absent.isNegative) return hunger.clamp(0.0, maxHunger);
    return (hunger + perSecond * absent.inMilliseconds / 1000.0).clamp(0.0, maxHunger);
  }

  /// 隨時間累積飢餓（由 controller 每幀呼叫）
  void tick(Duration elapsed) {
    _setHunger(_hunger + hungerPerSecond * elapsed.inMilliseconds / 1000.0);
  }

  /// 進食後降低飢餓
  void feed({double amount = 40}) => _setHunger(_hunger - amount);

  void _setHunger(double value) {
    final clamped = value.clamp(0.0, maxHunger);
    // 數值完全沒變 → 什麼都不做。這條看起來微不足道的 early-return 是關鍵：
    // 沒有的話，「已餓透」（hunger 恆為 maxHunger）的狀態下每幀都算得出 atBoundary=true，
    // 於是 60 次/秒通知 UI —— 正好是這個類別最想省掉的那種空轉。
    if (clamped == _hunger) return;

    // 跨過門檻（isHungry 翻轉，PetBrain 與進度條顏色都看它）與抵達兩端，
    // 就算變化量不到 1 點也要通知。
    final crossedThreshold = (clamped >= hungryThreshold) != (_lastNotified >= hungryThreshold);
    final atBoundary = clamped == 0.0 || clamped == maxHunger;
    _hunger = clamped;

    if (!crossedThreshold && !atBoundary && (clamped - _lastNotified).abs() < _notifyGranularity) return;
    _lastNotified = clamped;
    notifyListeners();
  }
}
