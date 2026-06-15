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

  FrameAnimation? getAction(AnimationAction action) => actions[action];

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
