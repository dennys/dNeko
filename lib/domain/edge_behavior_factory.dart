import 'edge_behavior.dart';

/// 邊緣行為種類（對應 animation.json 的 "edgeBehavior" 欄位）
enum EdgeBehaviorType {
  walk, // 沿邊走
  turnBack, // 回頭往中央
}

/// 只負責：把設定字串轉成對應的 IEdgeBehavior 實例
class EdgeBehaviorFactory {
  const EdgeBehaviorFactory();

  /// [raw] 來自 JSON，如 "walk" / "turnBack"；未知或缺省時回退沿邊走
  IEdgeBehavior create(String? raw) {
    final type = _parse(raw);
    switch (type) {
      case EdgeBehaviorType.turnBack:
        return EdgeTurnBackBehavior();
      case EdgeBehaviorType.walk:
        return EdgeWalkBehavior();
    }
  }

  EdgeBehaviorType _parse(String? raw) {
    if (raw == null) return EdgeBehaviorType.walk;
    return EdgeBehaviorType.values.firstWhere(
      (e) => e.name.toLowerCase() == raw.toLowerCase(),
      orElse: () => EdgeBehaviorType.walk,
    );
  }
}