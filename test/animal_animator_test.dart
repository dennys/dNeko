import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dneko/data/models/animation_action.dart';
import 'package:dneko/data/models/animation_definition.dart';
import 'package:dneko/data/models/animal_resource.dart';
import 'package:dneko/data/services/animation_loader.dart';
import 'package:dneko/presentation/widgets/animal_animator.dart';

// 換动物时 action 常没（两动物都 sit 起手）：旧的 didUpdateWidget 只有看 action，
// so the widget kept the previous animal's frame list and window duration.
AnimalResource _resource(String id) => AnimalResource(
      animalId: id,
      displayName: id,
      localFolderPath: '',
      version: '1',
      isDownloaded: false,
      isBuiltIn: true,
      updatedAt: DateTime(2026, 11, 9),
    );

AnimalAnimationDefinition _definition(String id) => AnimalAnimationDefinition(
      animalId: id,
      displayName: id,
      frameWidth: 32,
      frameHeight: 32,
      actions: {
        AnimationAction.sit: FrameAnimation(
          frames: ['sit$id'],
          frameDurationMs: 200,
          loop: true,
        ),
      },
    );

/// 只有 Sit 的定義（beg／faint 都走借幀）；`withFaint: true` 時另外宣告專屬 Faint 素材。
AnimalAnimationDefinition _borrowDef({bool withFaint = false}) => AnimalAnimationDefinition(
      animalId: 'cat',
      displayName: 'cat',
      frameWidth: 32,
      frameHeight: 32,
      actions: {
        AnimationAction.sit: const FrameAnimation(
          frames: ['sit1', 'sit2'],
          frameDurationMs: 200,
          loop: true,
        ),
        if (withFaint)
          AnimationAction.faint: const FrameAnimation(
            frames: ['faint1', 'faint2'],
            frameDurationMs: 200,
            loop: true,
          ),
      },
    );

Widget _pet(AnimalAnimationDefinition def, AnimationAction action) => MaterialApp(
      home: AnimalAnimator(
        resource: _resource(def.animalId),
        definition: def,
        action: action,
        loader: AnimationLoader(),
        displayWidth: 100,
        displayHeight: 100,
      ),
    );

/// 包著寵物圖的那層 Transform（不會抓到大層級自己的 Transform）
Finder petTransforms() => find.ancestor(of: find.byType(Image), matching: find.byType(Transform));

// 不靠 Transform 的先後順序（find.ancestor 把離圖近的排前面），直接從矩陣讀：平移量在 [13]、旋轉的 sin 在 [1]
double _dip(WidgetTester tester) => tester
    .widgetList<Transform>(petTransforms())
    .map((t) => t.transform.storage[13].abs())
    .fold<double>(0, (a, y) => y > a ? y : a);

double _sinRotation(WidgetTester tester) => tester
    .widgetList<Transform>(petTransforms())
    .map((t) => t.transform.storage[1].abs())
    .fold<double>(0, (a, s) => s > a ? s : a);

void main() {
  testWidgets('swapping the animal keeps the action but swaps the frames',
      (tester) async {
    final loader = AnimationLoader();
    Widget app(String id) => MaterialApp(
      home: AnimalAnimator(
        resource: _resource(id),
        definition: _definition(id),
        action: AnimationAction.sit,
        loader: loader,
      ),
    );

    await tester.pumpWidget(app('cat'));
    Image shown = tester.widget(find.byType(Image));
    expect((shown.image as AssetImage).assetName, 'assets/animals/cat/sitcat.png');

    await tester.pumpWidget(app('dog'));
    shown = tester.widget(find.byType(Image));
    expect((shown.image as AssetImage).assetName, 'assets/animals/dog/sitdog.png');
  });

  // 餓昏那兩格現在是 5 秒的長演（見 PetController._begHold），而八隻動物都沒畫 Beg／Faint 的幀
  // —— 看得見牠在拜/在倒完全是 AnimalAnimator 疊的程式化作動，所以這幾條就是那個演出的守門員。
  testWidgets('借幀的討食：一伏一伏地拜，不是一路停在同一格', (tester) async {
    await tester.pumpWidget(_pet(_borrowDef(), AnimationAction.beg));

    final offsets = <double>{};
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      offsets.add(_dip(tester));
    }
    // Transform.translate 會把平移量對齊到整數像素，所以伏身只有 0..6 幾階；
    // 重點是「有起有落」：全程同一個值就是卡在最後一帧，等於根本沒在拜。
    expect(offsets.any((y) => y > 0.5), isTrue, reason: '5 秒下來完全沒伏身');
    expect(offsets.length, greaterThan(1), reason: '只見過一個伏身量 = 停在同一格');
  });

  testWidgets('借幀的裝死：倒下後就攤著，不會每個循環重新倒一次', (tester) async {
    await tester.pumpWidget(_pet(_borrowDef(), AnimationAction.faint));

    await tester.pump(const Duration(milliseconds: 300)); // 一輪 400ms（2 幀×200ms）內倒完
    expect(_sinRotation(tester), greaterThan(0.9), reason: '沒倒平（sin 角度太小）');
    final down = (_sinRotation(tester), _dip(tester));

    await tester.pump(const Duration(milliseconds: 500)); // 已跨過兩個循環邊界
    expect((_sinRotation(tester), _dip(tester)), down,
        reason: '躺平的姿勢變了 = 控制器還在循環，會看到牠重新站起來再倒');
  });

  testWidgets('有專屬 Faint 素材時不疊程式化作動（由素材自己演，不會疊成「真素材在倒＋又被轉 80 度」）',
      (tester) async {
    await tester.pumpWidget(_pet(_borrowDef(withFaint: true), AnimationAction.faint));

    await tester.pump(const Duration(milliseconds: 300));
    expect(petTransforms(), findsNothing);
  });
}
