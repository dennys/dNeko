import 'animation_action.dart';

/// 一組動作的幀資料。
///
/// 這個物件的資料來自**下載下來的** animation.json，屬於不可信輸入，
/// 所以在这里就把不合法的挡掉（空幀清單、0/負的幀長）——
/// 否則到時候是 `AnimalAnimator` 在 `(progress * 0).floor().clamp(0, -1)` 那行丟
/// RangeError，畫面直接黑掉而且看不出來是素材的問題。
class FrameAnimation {
  final List<String> frames;
  final int frameDurationMs;
  final bool loop;

  const FrameAnimation({
    required this.frames,
    required this.frameDurationMs,
    required this.loop,
  });

  factory FrameAnimation.fromJson(Map<String, dynamic> json, String actionName) {
    final raw = json['frames'];
    if (raw is! List || raw.isEmpty || raw.any((e) => e is! String)) {
      throw FormatException('$actionName 的 frames 必須是非字串的字串清單', json);
    }
    final duration = json['frameDurationMs'];
    if (duration is! int || duration <= 0) {
      throw FormatException('$actionName 的 frameDurationMs 必須是正整數', json);
    }
    if (json['loop'] is! bool) {
      throw FormatException('$actionName 缺少 bool 的 loop', json);
    }

    return FrameAnimation(
      frames: List<String>.unmodifiable(raw.cast<String>()),
      frameDurationMs: duration,
      loop: json['loop'] as bool,
    );
  }
}

class AnimalAnimationDefinition {
  final String animalId;
  final String displayName;
  final int frameWidth;
  final int frameHeight;
  final String? edgeBehavior; // 個性（"walk" / "turnBack"）
  final Map<AnimationAction, FrameAnimation> actions;

  const AnimalAnimationDefinition({
    required this.animalId,
    required this.displayName,
    required this.frameWidth,
    required this.frameHeight,
    required this.actions,
    this.edgeBehavior,
  });

  FrameAnimation? getAction(AnimationAction action) {
    final direct = actions[action];
    if (direct != null) return direct;
    final alias = _missingFrameAlias[action];
    return alias == null ? null : actions[alias];
  }

  /// 素材沒有水平走的幀（貓只有 walk_u / walk_d 兩組），水平移動就借用往下走的幀。
  /// shortcut: 左右走看起來像在往下走；補到真正的 walk_l/r 素材後整張表可以刪掉
  /// （actions 有直接命中就不會走到這裡）。
  static const Map<AnimationAction, AnimationAction> _missingFrameAlias = {
    AnimationAction.walkLeft: AnimationAction.walkDown,
    AnimationAction.walkRight: AnimationAction.walkDown,
    AnimationAction.walkUpLeft: AnimationAction.walkUp,
    AnimationAction.walkUpRight: AnimationAction.walkUp,
    AnimationAction.walkDownLeft: AnimationAction.walkDown,
    AnimationAction.walkDownRight: AnimationAction.walkDown,
  };

  /// 解析 animation.json。任何一個欄位不對就丟 [FormatException]，
  /// 由呼叫端（overlay 的載入 try/catch）退回佔位小精靈，而不是讓 UI 崩。
  factory AnimalAnimationDefinition.fromJson(Map<String, dynamic> json) {
    String requireString(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty) throw FormatException('$key 必須是非空字串', json);
      return value;
    }

    int requirePositiveInt(String key) {
      final value = json[key];
      if (value is! int || value <= 0) throw FormatException('$key 必須是正整數', json);
      return value;
    }

    final rawActions = json['actions'];
    if (rawActions is! Map || rawActions.isEmpty) {
      throw FormatException('actions 至少要有動作可用', json);
    }

    final actions = <AnimationAction, FrameAnimation>{};
    for (final entry in rawActions.entries) {
      final name = entry.key;
      if (name is! String) continue;
      final action = AnimationAction.values.firstWhereOrNull(
        (e) => e.name == _toCamelCase(name),
      );
      // 認不出的動作名稱跳過就好：素材多給幾個動作不該让整个動物載入失敗。
      if (action == null) continue;
      final value = entry.value;
      if (value is! Map) continue;
      actions[action] = FrameAnimation.fromJson(Map<String, dynamic>.from(value), name);
    }

    if (actions.isEmpty) throw FormatException('actions 裡沒有任何可辨識的動作', json);

    return AnimalAnimationDefinition(
      animalId: requireString('animalId'),
      displayName: requireString('displayName'),
      frameWidth: requirePositiveInt('frameWidth'),
      frameHeight: requirePositiveInt('frameHeight'),
      edgeBehavior: json['edgeBehavior'] is String ? json['edgeBehavior'] as String : null,
      actions: actions,
    );
  }

  static String _toCamelCase(String s) => s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);
}

extension IterableX<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
