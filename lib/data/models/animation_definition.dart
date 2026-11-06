import 'animation_action.dart';

class FrameAnimation {
  final List<String> frames;
  final int frameDurationMs;
  final bool loop;

  const FrameAnimation({
    required this.frames,
    required this.frameDurationMs,
    required this.loop,
  });

  factory FrameAnimation.fromJson(Map<String, dynamic> json) => FrameAnimation(
        frames: List<String>.from(json['frames']),
        frameDurationMs: json['frameDurationMs'] as int,
        loop: json['loop'] as bool,
      );
}

class AnimalAnimationDefinition {
  final String animalId;
  final String displayName;
  final int frameWidth;
  final int frameHeight;
  final String? edgeBehavior; // 新增：個性（"walk" / "turnBack"）
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

  factory AnimalAnimationDefinition.fromJson(Map<String, dynamic> json) {
    final rawActions = json['actions'] as Map<String, dynamic>;
    final actions = <AnimationAction, FrameAnimation>{};

    for (final entry in rawActions.entries) {
      final action = AnimationAction.values.firstWhereOrNull(
        (e) => e.name == _toCamelCase(entry.key),
      );
      if (action != null) {
        actions[action] = FrameAnimation.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }
    }

    return AnimalAnimationDefinition(
      animalId: json['animalId'] as String,
      displayName: json['displayName'] as String,
      frameWidth: json['frameWidth'] as int,
      frameHeight: json['frameHeight'] as int,
      edgeBehavior: json['edgeBehavior'] as String?, // 可選
      actions: actions,
    );
  }

  static String _toCamelCase(String s) => s[0].toLowerCase() + s.substring(1);
}

extension IterableX<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
