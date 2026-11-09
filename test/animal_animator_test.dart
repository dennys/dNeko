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
}
