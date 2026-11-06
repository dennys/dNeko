import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dneko/data/models/animation_action.dart';
import 'package:dneko/data/models/animation_definition.dart';

/// 貓的 animation.json 只有 WalkUp / WalkDown 兩組走路幀，沒有水平走的。
/// 水平移動時借用到對角/垂直的幀，這裡鎖住那個對應關係。
Map<String, dynamic> _json(List<String> actions) => {
      'animalId': 'cat',
      'displayName': '小花貓',
      'frameWidth': 32,
      'frameHeight': 32,
      'actions': {
        for (final a in actions)
          a: {'frames': ['${a.toLowerCase()}1'], 'frameDurationMs': 250, 'loop': true},
      },
    };

void main() {
  group('AnimalAnimationDefinition 缺水平幀的對應', () {
    test('只有 WalkUp/WalkDown 時，水平走借幀', () {
      final def = AnimalAnimationDefinition.fromJson(
        jsonDecode(jsonEncode(_json(['WalkUp', 'WalkDown', 'Sit']))) as Map<String, dynamic>,
      );

      expect(def.getAction(AnimationAction.walkLeft)!.frames, ['walkdown1']);
      expect(def.getAction(AnimationAction.walkRight)!.frames, ['walkdown1']);
      expect(def.getAction(AnimationAction.walkUpRight)!.frames, ['walkup1']);
      expect(def.getAction(AnimationAction.walkDownLeft)!.frames, ['walkdown1']);
    });

    test('素材有 WalkLeft 時用自己的，不被借幀蓋掉', () {
      final def = AnimalAnimationDefinition.fromJson(
        jsonDecode(jsonEncode(_json(['WalkUp', 'WalkDown', 'WalkLeft']))) as Map<String, dynamic>,
      );

      expect(def.getAction(AnimationAction.walkLeft)!.frames, ['walkleft1']);
    });

    test('非走路動作缺幀仍然回 null（讓 AnimalAnimator 的後備接手）', () {
      final def = AnimalAnimationDefinition.fromJson(
        jsonDecode(jsonEncode(_json(['WalkDown']))) as Map<String, dynamic>,
      );

      expect(def.getAction(AnimationAction.eat), isNull);
      expect(def.getAction(AnimationAction.sleep), isNull);
    });
  });
}
