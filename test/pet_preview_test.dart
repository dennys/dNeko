import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dneko/data/models/animation_action.dart';
import 'package:dneko/data/models/animation_definition.dart';
import 'package:dneko/data/models/animal_resource.dart';
import 'package:dneko/data/repositories/i_animal_repository.dart';
import 'package:dneko/data/services/animation_loader.dart';
import 'package:dneko/domain/pet_settings.dart';
import 'package:dneko/presentation/widgets/animal_animator.dart';
import 'package:dneko/presentation/widgets/pet_preview.dart';

/// 只測「預覽塊有沒有把輸入接到控制器上」與「慢的載入不能覆蓋新的」。
/// 走位/餵食的手感是 PetController 的事（已有 pet_controller_test），真機 P-3 驗。

AnimalResource _resource(String id) => AnimalResource(
      animalId: id,
      displayName: id,
      localFolderPath: '/tmp/$id',
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
        AnimationAction.sit: const FrameAnimation(frames: ['sit'], frameDurationMs: 200, loop: true),
        AnimationAction.walkDown: const FrameAnimation(frames: ['wd1', 'wd2'], frameDurationMs: 200, loop: true),
        AnimationAction.affectionate: const FrameAnimation(frames: ['pet'], frameDurationMs: 200, loop: true),
      },
    );

class _FakeRepo implements IAnimalRepository {
  /// 每個 id 要等哪個 Completer 才回；沒列在裡的直接回資源
  final Map<String, Completer<AnimalResource?>> gates = {};
  final List<String> resolveCalls = [];

  @override
  Future<AnimalResource?> resolveResource(String animalId) async {
    resolveCalls.add(animalId);
    return await (gates[animalId]?.future ?? Future.value(_resource(animalId)));
  }

  @override
  Future<AnimalResource?> getById(String animalId) async => _resource(animalId);
  @override
  Future<List<AnimalResource>> getAll() async => [];
  @override
  Future<List<AnimalResource>> getDownloaded() async => [];
  @override
  Future<void> upsert(AnimalResource resource) async {}
  @override
  Future<void> delete(String animalId) async {}
}

/// 不碰 assets/檔案系統：definition 直接給，圖片給一張必定解碼失敗的（AnimalAnimator
/// 有 errorBuilder，走位判斷不受影響）
class _FakeLoader implements AnimationLoader {
  final List<String> loaded = [];
  bool fail = false;

  @override
  Future<AnimalAnimationDefinition> load(AnimalResource resource) async {
    loaded.add(resource.animalId);
    if (fail) throw Exception('素材不见了');
    return _definition(resource.animalId);
  }

  @override
  ImageProvider getFrameImage(AnimalResource resource, String frameName) =>
      MemoryImage(Uint8List.fromList(const [0]));
}

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

Future<void> _pumpUntilLoaded(WidgetTester tester) async {
  for (var i = 0; i < 20 && find.byType(AnimalAnimator).evaluate().isEmpty; i++) {
    await tester.pump();
  }
}

void main() {
  PetPreview build(PetSettings settings, _FakeRepo repo, _FakeLoader loader) => PetPreview(
        settings: settings,
        repository: repo,
        loader: loader,
      );

  const settings = PetSettings(animalId: 'cat', petSize: 80, speedPxPerSecond: 60);

  testWidgets('載入成功就顯示同一套 AnimalAnimator', (tester) async {
    final repo = _FakeRepo();
    final loader = _FakeLoader();
    await tester.pumpWidget(_host(build(settings, repo, loader)));
    await _pumpUntilLoaded(tester);

    final animator = tester.widget<AnimalAnimator>(find.byType(AnimalAnimator));
    expect(animator.resource.animalId, 'cat');
    expect(animator.definition.animalId, 'cat');
    expect(animator.displayWidth, settings.petSize);
  });

  testWidgets('短按 = 撫摸（接到 PetController.pet()）', (tester) async {
    await tester.pumpWidget(_host(build(settings, _FakeRepo(), _FakeLoader())));
    await _pumpUntilLoaded(tester);

    expect(tester.widget<AnimalAnimator>(find.byType(AnimalAnimator)).action, isNot(AnimationAction.affectionate));
    await tester.tap(find.byType(PetPreview));
    // 同一個 GestureDetector 上還有 onDoubleTap → 單按要等 300ms 辨認期才會真的發 onTap，
    // 用 pump()（零時間）是等不到的
    await tester.pump(const Duration(milliseconds: 350));

    expect(tester.widget<AnimalAnimator>(find.byType(AnimalAnimator)).action, AnimationAction.affectionate);
  });

  testWidgets('載入失敗給一個可按重試的佔位，按它會再問一次', (tester) async {
    final repo = _FakeRepo();
    final loader = _FakeLoader()..fail = true;
    await tester.pumpWidget(_host(build(settings, repo, loader)));
    await _pumpUntilLoaded(tester);

    expect(find.byType(AnimalAnimator), findsNothing);
    expect(find.byIcon(Icons.pets), findsOneWidget);

    loader.fail = false;
    await tester.tap(find.byIcon(Icons.pets));
    await _pumpUntilLoaded(tester);

    expect(find.byType(AnimalAnimator), findsOneWidget);
    expect(repo.resolveCalls, ['cat', 'cat']);
  });

  testWidgets('換動物時，慢的那一次載入不能覆蓋新的', (tester) async {
    final repo = _FakeRepo();
    final loader = _FakeLoader();
    final slowCat = Completer<AnimalResource?>();
    repo.gates['cat'] = slowCat;

    await tester.pumpWidget(_host(build(settings, repo, loader)));
    await tester.pump();

    // 換成狗（狗馬上就回），貓那一次還掛在那裡
    const dog = PetSettings(animalId: 'dog', petSize: 80, speedPxPerSecond: 60);
    await tester.pumpWidget(_host(build(dog, repo, loader)));
    await _pumpUntilLoaded(tester);
    expect(tester.widget<AnimalAnimator>(find.byType(AnimalAnimator)).resource.animalId, 'dog');

    // 貓現在才回：舊請求必須整個丟掉，連素材都不該去載
    slowCat.complete(_resource('cat'));
    await tester.pump();
    await tester.pump();

    expect(loader.loaded, ['dog']);
    expect(tester.widget<AnimalAnimator>(find.byType(AnimalAnimator)).resource.animalId, 'dog');
  });
}
