import 'dart:math';

import 'pet_behavior.dart';

/// 發呆／漫遊時的隨機小動作排程（純邏輯，不依賴 Flutter）。
///
/// 每分鐘約 [chancePerMinute] 的機率觸發一次，觸發後進入 [cooldown] 冷卻，
/// 避免牠一直抽風。機率依實際經過的時間換算，tick 頻率改了機率不會跟著變。
class FlourishScheduler {
  FlourishScheduler({
    Random? random,
    this.chancePerMinute = 0.25,
    this.cooldown = const Duration(seconds: 30),
  }) : _random = random ?? Random();

  final Random _random;
  final double chancePerMinute;
  final Duration cooldown;

  /// 剩餘冷卻時間；0 表示可以抽。
  Duration _cooldownLeft = Duration.zero;

  /// 推進 [elapsed] 時間後，有機會就從 [candidates] 挑一個回傳；否則回傳 null。
  /// 候選為空時不消耗機率，也不進入冷卻。
  PetBehavior? tryPick(Duration elapsed, List<PetBehavior> candidates) {
    if (_cooldownLeft > elapsed) {
      _cooldownLeft -= elapsed;
      return null;
    }
    _cooldownLeft = Duration.zero;
    if (candidates.isEmpty) return null;

    final minutes = elapsed.inMicroseconds / Duration.microsecondsPerMinute;
    final chance = 1 - pow(1 - chancePerMinute, minutes).toDouble();
    if (_random.nextDouble() >= chance) return null;

    _cooldownLeft = cooldown;
    return candidates[_random.nextInt(candidates.length)];
  }
}
