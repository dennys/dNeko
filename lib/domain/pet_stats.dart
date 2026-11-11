import 'package:flutter/foundation.dart';

import 'pet_bond.dart';

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

  /// 「這個餓度算不算餓」的**唯一**判準 —— PetBrain 的決策與 HungerBar 的顏色都走這裡。
  ///
  /// 用 `>` 不用 `>=`：餵食量是 40，從餓透（100）餵一次剛好落在門檻 60 上；用 `>=` 會判成
  /// 「仍然餓」→ 要餵兩次才脫餓，而餓的時候 PetBrain 絕不睡覺（使用者餵完卻看到牠照常只走
  /// 不睡，像餵了沒反應）。以前判準在 PetStats 與 HungerBar 各寫一份 `>=`，改一邊必漏另一邊。
  static bool isHungryAt(double hunger, double threshold) => hunger > threshold;

  /// 是否餓到想找食物
  bool get isHungry => isHungryAt(_hunger, hungryThreshold);

  /// 餓的門檻（點數）。改動要走 [setHungryThreshold]（要通知 isHungry 翻轉）
  double hungryThreshold;

  /// 改門檻（設定頁即時生效）；只有 isHungry 狀態翻轉才通知（PetBrain 與進度條顏色都看它）
  void setHungryThreshold(double value) {
    if (value == hungryThreshold) return;
    final wasHungry = isHungryAt(_hunger, hungryThreshold);
    hungryThreshold = value;
    if (isHungryAt(_hunger, value) != wasHungry) notifyListeners();
  }

  // ===== 親密度（只漲不跌；規格與「為什麼是這個數」都寫在 PetBond）=====

  PetBond _bond;
  PetBond get bond => _bond;

  /// 給 PetBrain 當決策權重用（0~100）
  double get bondValue => _bond.value;

  /// 摸一下計分。**計不計分由呼叫端決定**：只有懸浮那側該計（預覽塊是沙箱、不讀不寫 DB，
  /// 而且「定格時摸牠無效」也不該加分）。回傳 false = 今天的額度已用完 → 不驚動 listener。
  bool awardPet(DateTime now) => _applyBond(_bond.awardPet(now));

  /// 真的吃下一口才計分（不是「丟出食物」那一刻）
  bool awardFeed(DateTime now) => _applyBond(_bond.awardFeed(now));

  bool _applyBond(PetBond next) {
    if (next.value == _bond.value) return false; // 額度用盡/已滿：別空轉 notifyListeners
    _bond = next;
    notifyListeners();
    return true;
  }

  /// 每秒增加的飢餓值
  final double hungerPerSecond;

  PetStats({
    double initialHunger = 0,
    PetBond? initialBond,
    this.hungryThreshold = defaultHungryThreshold,
    this.hungerPerSecond = defaultHungerPerSecond,
  })  : _bond = initialBond ?? const PetBond(),
        _hunger = initialHunger.clamp(0.0, maxHunger),
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
    final crossedThreshold =
        isHungryAt(clamped, hungryThreshold) != isHungryAt(_lastNotified, hungryThreshold);
    final atBoundary = clamped == 0.0 || clamped == maxHunger;
    _hunger = clamped;

    if (!crossedThreshold && !atBoundary && (clamped - _lastNotified).abs() < _notifyGranularity) return;
    _lastNotified = clamped;
    notifyListeners();
  }
}
