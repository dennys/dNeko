import 'dart:ui';

/// 「這次位置要不要寫盤」的節流判定（純邏輯，不碰平台，方便測）。
///
/// 懸浮是長期開著的東西，而 `PetController` 每個 tick（16ms）就 notify 一次；沒有節流
/// 等於為一個「下次出現在哪」每秒寫 60 筆 DB。兩個條件要**同時**成立才寫：
/// 離上次存盤至少 [interval]、且離上次存盤的位置至少 [minMovePx]。
/// 靜止的寵物（idle／sleep／凍結）位置不動 → 一筆都不寫。
///
/// 代價：重開時寵物可能出現在最多 [interval] 前、[minMovePx] 內的位置 —— 那個時刻使用者
/// 並不會看著螢幕。確定要留檔的時刻（收選單、按結束）走 `force`，繞過這裡。
class PositionThrottle {
  PositionThrottle({
    this.minMovePx = 50,
    this.interval = const Duration(seconds: 5),
  });

  final double minMovePx;
  final Duration interval;

  Offset? _lastSaved;
  DateTime? _lastSave;

  /// 位置 [p]（時刻 [now]）現在該不該寫盤。說 yes 之後呼叫端真的寫完了要回報 [didSave]，
  /// 否則這裡永遠回答 yes（變成每 tick 寫一筆）。
  bool shouldSave(Offset p, DateTime now) {
    final last = _lastSaved;
    if (last != null && (p - last).distance < minMovePx) return false;
    final at = _lastSave;
    if (at != null && now.difference(at) < interval) return false;
    return true;
  }

  /// 記下「這一刻存了這個位置」：基準點與基準時間一起更新（只更新其中一個會失準）
  void didSave(Offset p, DateTime now) {
    _lastSaved = p;
    _lastSave = now;
  }
}
