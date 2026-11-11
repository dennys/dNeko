import 'dart:convert';

/// 親密度：純計分規則（存盤在 SettingsRepository，顯示在選單那條餓度旁）。
///
/// 人類 2026-11-11 定的規格：
/// * **只漲不跌、不隨時間衰減、不做等級**（要「不陪會生疏」再說，那時要先解決「使用者不知道
///   自己做錯什麼」的挫折）。
/// * **不影響餓度／進食效率** —— 「餓」的判定只有 [PetStats.isHungry] 一個來源，
///   再塞第二個會開始互相蓋（實測過：舊版「撒嬌 +20 hunger」能把 92 壓回 79，讓 80 的閾值失效）。
/// * **每隻動物各一份**（存盤 key = `pet_bond_<animalId>`）—— 「這隻是我養的」與「我對貓好」語意不同。
/// * 舊安裝沒有這欄 → 就從 0 開始算，不做遷移（人類的決定：不要管舊安裝）。
///
/// 它唯一的**後果**是 [PetBrain] 越高機率主動撒嬌；沒有後果的數值只是計數器，不配叫親密度。
class PetBond {
  const PetBond({this.value = 0, this.day = '', this.petTally = 0, this.feedTally = 0});

  static const double maxBond = 100;

  /// 一次互動給多少分、一天最多計幾次。
  /// 額度是**防刷**用的：沒有它，連點 100 次摸牠就能把親密度刷滿，整個機制三天就廢。
  static const double petAward = 2;
  static const double feedAward = 5;
  static const int petDailyCap = 3;
  static const int feedDailyCap = 2;

  final double value;

  /// 計分日（本地日期字樣）。跨天就把兩個 tally 歸零 —— 「一天最多計幾次」需要記得今天是哪天。
  final String day;
  final int petTally;
  final int feedTally;

  static String dayOf(DateTime now) =>
      '${now.year}-${now.month.toString().padLeft(2, "0")}-${now.day.toString().padLeft(2, "0")}';

  /// 摸一下（今天的前 [petDailyCap] 次才算分）
  PetBond awardPet(DateTime now) => _advance(now, petTally, petDailyCap, petAward, isPet: true);

  /// 吃下一口（今天的前 [feedDailyCap] 次才算分）
  PetBond awardFeed(DateTime now) =>
      _advance(now, feedTally, feedDailyCap, feedAward, isPet: false);

  PetBond _advance(DateTime now, int tally, int cap, double award, {required bool isPet}) {
    if (value >= maxBond) return this;
    final today = dayOf(now);
    final counted = day == today ? tally : 0; // 跨天歸零
    if (counted >= cap) return this;
    return PetBond(
      value: (value + award).clamp(0.0, maxBond),
      day: today,
      petTally: isPet ? counted + 1 : petTally,
      feedTally: isPet ? feedTally : counted + 1,
    );
  }

  String encode() => jsonEncode({
        'bond': double.parse(value.toStringAsFixed(2)),
        'day': day,
        'pet': petTally,
        'feed': feedTally,
      });

  /// 沒存過或格式壞掉回 null（讓呼叫端決定預設，而不是在這裡猜）
  static PetBond? decode(String? raw) {
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final value = (decoded['bond'] as num?)?.toDouble();
      if (value == null) return null;
      return PetBond(
        value: value.clamp(0.0, maxBond),
        day: decoded['day'] as String? ?? '',
        petTally: (decoded['pet'] as num?)?.toInt() ?? 0,
        feedTally: (decoded['feed'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}
