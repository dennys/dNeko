import 'dart:convert';
import 'dart:io';
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

    test('素材有 WalkSide 時水平走用它；往右走才鏡像', () {
      final def = AnimalAnimationDefinition.fromJson(
        jsonDecode(jsonEncode(_json(['WalkUp', 'WalkDown', 'WalkSide']))) as Map<String, dynamic>,
      );

      expect(def.getAction(AnimationAction.walkLeft)!.frames, ['walkside1']);
      expect(def.getAction(AnimationAction.walkRight)!.frames, ['walkside1']);
      expect(def.mirrorsSideFor(AnimationAction.walkRight), isTrue);
      expect(def.mirrorsSideFor(AnimationAction.walkLeft), isFalse);
    });

    test('沒有 WalkSide 時不鏡像，仍借 walk_d', () {
      final def = AnimalAnimationDefinition.fromJson(
        jsonDecode(jsonEncode(_json(['WalkUp', 'WalkDown']))) as Map<String, dynamic>,
      );

      expect(def.mirrorsSideFor(AnimationAction.walkRight), isFalse);
    });

    test('非走路動作缺幀仍然回 null（讓 AnimalAnimator 的後備接手）', () {
      final def = AnimalAnimationDefinition.fromJson(
        jsonDecode(jsonEncode(_json(['WalkDown']))) as Map<String, dynamic>,
      );

      expect(def.getAction(AnimationAction.eat), isNull);
      expect(def.getAction(AnimationAction.sleep), isNull);
    });
  });

  // animation.json 是**下載下來的**檔案（動物商店），屬於不可信輸入。
  // 以前完全沒驗證：空幀清單会让 AnimalAnimator 在 clamp(0, -1) 丟 RangeError，
  // 使用者看到的是整隻寵物不見，而且看不出是素材壞了。
  group('AnimalAnimationDefinition 驗證不可信輸入', () {
    Map<String, dynamic> jsonWith(Map<String, dynamic> action) => {
          'animalId': 'fox',
          'displayName': '小狐狸',
          'frameWidth': 32,
          'frameHeight': 32,
          'actions': {'Sit': action},
        };

    test('空幀清單直接被挡掉', () {
      expect(
        () => AnimalAnimationDefinition.fromJson(jsonWith({'frames': <String>[], 'frameDurationMs': 250, 'loop': true})),
        throwsFormatException,
      );
    });

    test('frames 不是字串清單也挡掉', () {
      expect(
        () => AnimalAnimationDefinition.fromJson(jsonWith({'frames': [1, 2], 'frameDurationMs': 250, 'loop': true})),
        throwsFormatException,
      );
    });

    test('frameDurationMs 為 0 或不是整數時挡掉（否则 AnimationController 直接炸）', () {
      for (final bad in [0, -1, '250', null]) {
        expect(
          () => AnimalAnimationDefinition.fromJson(jsonWith({'frames': ['sit1'], 'frameDurationMs': bad, 'loop': true})),
          throwsFormatException,
          reason: 'frameDurationMs = $bad 應該要擋掉',
        );
      }
    });

    test('缺 loop 或型別不對時挡掉', () {
      expect(
        () => AnimalAnimationDefinition.fromJson(jsonWith({'frames': ['sit1'], 'frameDurationMs': 250})),
        throwsFormatException,
      );
    });

    test('frameWidth/animalId 等欄位不對時挡掉', () {
      final broken = jsonWith({'frames': ['sit1'], 'frameDurationMs': 250, 'loop': true})..['frameWidth'] = 0;
      expect(() => AnimalAnimationDefinition.fromJson(broken), throwsFormatException);
    });

    test('actions 空或全部認不出時挡掉', () {
      expect(
        () => AnimalAnimationDefinition.fromJson({
          'animalId': 'fox', 'displayName': '小狐狸', 'frameWidth': 32, 'frameHeight': 32, 'actions': {},
        }),
        throwsFormatException,
      );
      expect(
        () => AnimalAnimationDefinition.fromJson({
          'animalId': 'fox', 'displayName': '小狐狸', 'frameWidth': 32, 'frameHeight': 32,
          'actions': {'Dance': {'frames': ['d1'], 'frameDurationMs': 100, 'loop': true}},
        }),
        throwsFormatException,
      );
    });

    test('素材多給不認識的動作不會讓整隻動物載入失敗', () {
      final def = AnimalAnimationDefinition.fromJson({
        'animalId': 'fox',
        'displayName': '小狐狸',
        'frameWidth': 32,
        'frameHeight': 32,
        'actions': {
          'Sit': {'frames': ['sit1'], 'frameDurationMs': 250, 'loop': true},
          'Dance': {'frames': ['d1'], 'frameDurationMs': 100, 'loop': true},
        },
      });
      expect(def.getAction(AnimationAction.sit)!.frames, ['sit1']);
      expect(def.actions.length, 1);
    });

    test('隨附的內建素材都過得了驗證', () {
      for (final id in ['cat', 'dog']) {
        final raw = File('assets/animals/$id/animation.json').readAsStringSync();
        final def = AnimalAnimationDefinition.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        expect(def.animalId, id);
        expect(def.actions.isNotEmpty, isTrue);
        for (final action in def.actions.values) {
          expect(action.frames, isNotEmpty);
          expect(action.frameDurationMs, greaterThan(0));
        }
      }
    });
  });
}
