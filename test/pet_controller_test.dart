import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:dneko/data/models/animation_action.dart';
import 'package:dneko/data/models/animation_definition.dart';
import 'package:dneko/domain/i_pet_brain.dart';
import 'package:dneko/domain/pet_behavior.dart';
import 'package:dneko/domain/pet_decision.dart';
import 'package:dneko/domain/pet_stats.dart';
import 'package:dneko/presentation/controllers/pet_controller.dart';
import 'package:dneko/presentation/controllers/pet_controller_factory.dart';

/// 用 testWidgets 的假時鐘推動 PetController 的 16ms 主迴圈（不必多拉依賴）
void main() {
  const tick = Duration(milliseconds: 16);

  PetController make({
    required Rect bounds,
    double? speedPerTick,
    IPetBrain? brain,
  }) {
    final controller = PetController(
      bounds: bounds,
      speedPerTick: speedPerTick,
      brain: brain,
      stats: PetStats(initialHunger: 50),
    )..start();
    return controller;
  }

  Future<void> pumpTicks(WidgetTester tester, int n) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(tick);
    }
  }

  group('PetController 設定相關', () {
    testWidgets('speedPerTick 決定每幀走的距離', (tester) async {
      final c = make(
        bounds: const Rect.fromLTWH(0, 0, 1000, 1000),
        speedPerTick: 10,
      );
      c.feedAt(const Offset(500, 900)); // 正下方
      await pumpTicks(tester, 1);

      expect(c.position, const Offset(500, 510)); // 從 bounds.center 起算
      c.dispose(); // 在 test body 内關 timer，留到 teardown 会被 flutter_test 當洩漏
    });

    testWidgets('setSpeedPerTick 即時生效', (tester) async {
      final c = make(
        bounds: const Rect.fromLTWH(0, 0, 1000, 1000),
        speedPerTick: 5,
      );
      c.feedAt(const Offset(500, 900));
      c.setSpeedPerTick(20);
      await pumpTicks(tester, 1);

      expect(c.position, const Offset(500, 520));
      c.dispose();
    });

    testWidgets('食物落在範圍外會被夾回來，走得到店並進食', (tester) async {
      final c = make(
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        speedPerTick: 10,
      );
      c.feedAt(const Offset(500, 50)); // 超出右邊界
      await pumpTicks(tester, 8);

      expect(c.action, AnimationAction.eat);
      expect(c.position.dx, 100);
      expect(c.stats.hunger, lessThan(20)); // 起始 50，吃一次 -40（行走累積不致補回來）
      c.dispose();
    });

    testWidgets('onFed 只在「真的走到並吃掉」那一刻觸發一次（餵食的親密度計分掛它）', (tester) async {
      final c = make(
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        speedPerTick: 10,
      );
      var fed = 0;
      c.onFed = () => fed++;

      c.feedAt(const Offset(500, 50)); // 超出右邊界 → 夾到 (100,50)，要走幾格才到
      await pumpTicks(tester, 2);
      expect(fed, 0, reason: '食物剛丟下去、還沒走到就不算吃過');
      await pumpTicks(tester, 6);
      expect(c.action, AnimationAction.eat);
      // 若在「丟出食物」那一刻就計分，連點兩下就能刷滿一天的額度 —— 只能遲到抵達之後
      expect(fed, 1);

      await pumpTicks(tester, 30); // 吃完 → 吃的 hold → 下一次決定
      expect(fed, 1, reason: '一餐只計一次');
      c.dispose();

      // 自主行為永遠不會自己「吃到東西」：brain 只給 idle，跑 30 跳不該計到分
      final idle = make(
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        brain: _AlwaysIdleBrain(),
      );
      var idleFed = 0;
      idle.onFed = () => idleFed++;
      await pumpTicks(tester, 30);
      expect(idleFed, 0);
      idle.dispose();
    });

    testWidgets('updateBounds 之後拖曳會被夾在新範圍內', (tester) async {
      final c = make(bounds: const Rect.fromLTWH(0, 0, 1000, 1000));
      c.updateBounds(const Rect.fromLTWH(300, 700, 100, 100));
      c.beginDrag();
      c.syncFromWindow(const Offset(-500, -500)); // 拖曳中不 clamp（視窗跟手）
      c.endDrag(); // 放開才夾回 zone

      expect(c.bounds, const Rect.fromLTWH(300, 700, 100, 100));
      expect(c.position, const Offset(300, 700));
      c.dispose();
    });

    testWidgets('updateBounds 把留在舊區外的位置夾回新區（zone 切換不瞬移）', (tester) async {
      final c = make(bounds: const Rect.fromLTWH(0, 0, 1000, 1000));
      c.syncFromWindow(const Offset(900, 900)); // 先拖到右下角（舊區內）
      expect(c.position, const Offset(900, 900));

      // fullScreen → bottomLeft：舊位置 x 在新區外
      c.updateBounds(const Rect.fromLTWH(0, 700, 300, 300));
      expect(c.position, const Offset(300, 900)); // x 夾到新區右邊（y 本來就在區內）
      c.dispose();
    });

    testWidgets('endDrag 把拖出 zone 的位置夾回邊界（A-2/A-7）', (tester) async {
      final c = make(bounds: const Rect.fromLTWH(0, 0, 100, 100));
      c.beginDrag();
      c.syncFromWindow(const Offset(500, 500)); // 拖出 zone（拖曳中不 clamp）
      expect(c.position, const Offset(500, 500));
      c.endDrag();
      expect(c.position, const Offset(100, 100)); // 放開時夾回邊界
      c.dispose();
    });

    group('拖曳後餵食回歸（走動中雙擊餵食只能成功一次）', () {
      testWidgets('沒有 endDrag 時 isDragging 卡住，餵食不會走過去', (tester) async {
        final c = make(
          bounds: const Rect.fromLTWH(0, 0, 100, 100),
          speedPerTick: 10,
        );
        c.beginDrag(); // 走動中被誤判成拖曳，之後沒有 endDrag
        expect(c.isDragging, isTrue);

        c.feedAt(const Offset(500, 50));
        await pumpTicks(tester, 8);
        expect(c.action, isNot(AnimationAction.eat), reason: '卡在拖曳中 _onTick 直接早退');
        c.dispose();
      });

      testWidgets('endDrag 後 isDragging 清掉，餵食照常走到並吃', (tester) async {
        final c = make(
          bounds: const Rect.fromLTWH(0, 0, 100, 100),
          speedPerTick: 10,
        );
        var fed = 0;
        c.onFed = () => fed++;

        c.beginDrag();
        c.syncFromWindow(const Offset(50, 50));
        c.endDrag();
        expect(c.isDragging, isFalse);

        c.feedAt(const Offset(500, 50));
        await pumpTicks(tester, 8);
        expect(c.action, AnimationAction.eat);
        expect(fed, 1);
        c.dispose();
      });

      testWidgets('同一隻動物連續餵食多次都會成功（第二次沒反應的回歸）', (tester) async {
        final c = make(
          bounds: const Rect.fromLTWH(0, 0, 100, 100),
          speedPerTick: 10,
        );
        var fed = 0;
        c.onFed = () => fed++;

        c.feedAt(const Offset(500, 50));
        await pumpTicks(tester, 8);
        expect(fed, 1);

        // 等吃完 hold（900 ms）回到自主行為，再餵第二次
        await pumpTicks(tester, 80);
        c.feedAt(const Offset(0, 50));
        await pumpTicks(tester, 15);
        expect(fed, 2, reason: '第二次餵食也必須走到並吃掉');
        c.dispose();
      });
    });

    testWidgets('constructor 帶入舊位置會 clamp 到新 bounds（A-9a）', (tester) async {
      final c = PetController(
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        position: const Offset(500, 500), // 超出新 bounds
        stats: PetStats(initialHunger: 50),
      );
      expect(c.position, const Offset(100, 100)); // clamp 到新 bounds
      c.dispose();
    });

    testWidgets('constructor 不帶位置時預設 bounds.center', (tester) async {
      final c = PetController(
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        stats: PetStats(initialHunger: 50),
      );
      expect(c.position, const Offset(50, 50)); // bounds.center
      c.dispose();
    });
  });

  // 之前每 16ms 一定 notifyListeners()，overlay 那側就是固定 60 次/秒重建 widget；
  // 但桌寵大部分時間只是坐在那裡。通知要收在「看得見的變化」。
  group('通知節流', () {
    testWidgets('原地發呆不會每幀都通知', (tester) async {
      var notifications = 0;
      final c = PetController(
        bounds: const Rect.fromLTWH(0, 0, 1000, 1000),
        brain: _AlwaysIdleBrain(),
        stats: PetStats(initialHunger: 50),
      )..start();
      c.addListener(() => notifications++);

      await pumpTicks(tester, 1); // 第一幀把基準位置/動作記下來（這一次通知是必要的）
      final established = notifications;
      expect(established, 1);

      await pumpTicks(tester, 300); // 約 5 秒，都還在 idle 的 hold 裡
      expect(c.position, const Offset(500, 500));
      expect(notifications, established, reason: '位置與動作都沒變，不該再通知');
      c.dispose();
    });

    testWidgets('按撫摸會立刻通知（否則撒嬌動畫根本播不出來）', (tester) async {
      // pet() 只換動作、不動位置，而 hold=_affectionateHold 讓接下來的 75 幀都提前 return；
      // 少了 _enter 的通知，按下之後撒嬌動畫根本不會出現。
      final c = PetController(
        bounds: const Rect.fromLTWH(0, 0, 1000, 1000),
        brain: _AlwaysIdleBrain(),
        stats: PetStats(initialHunger: 50),
      )..start();
      var notifications = 0;
      c.addListener(() => notifications++);

      c.pet();
      expect(c.action, AnimationAction.affectionate);
      expect(notifications, 1);
      c.dispose();
    });

    testWidgets('定格時摸牠無效（否則會卡在撒嬌最後一幀直到解凍）', (tester) async {
      final c = PetController(
        bounds: const Rect.fromLTWH(0, 0, 1000, 1000),
        brain: _AlwaysIdleBrain(),
        stats: PetStats(initialHunger: 50),
      )..start();

      c.setFrozen(true);
      final before = c.action;
      // 回傳值要一起鎖：overlay 用它決定「這一下加不加親密度」。只鎖動畫的話，
      // 「回傳 true 但不播動畫」那種 regression 會變成「定格被摸一摸，隔天親密度憑空 +6」
      expect(c.pet(), isFalse);
      expect(c.action, before, reason: '定格就是動作固定不動（DEVICE_TEST 對 A-9a 的期待）');
      expect(c.action, isNot(AnimationAction.affectionate));

      // 解凍後摸牠照常撒嬌
      c.setFrozen(false);
      expect(c.pet(), isTrue);
      expect(c.action, AnimationAction.affectionate);
      c.dispose();
    });

    testWidgets('拖曳播 sit、不播撒嬌（外觀要分得出「被摸」與「被拖」）', (tester) async {
      final c = PetController(
        bounds: const Rect.fromLTWH(0, 0, 1000, 1000),
        brain: _AlwaysIdleBrain(),
        stats: PetStats(initialHunger: 50),
      );

      c.pet();
      expect(c.action, AnimationAction.affectionate);
      c.beginDrag();
      expect(c.action, AnimationAction.sit);
      c.dispose();
    });

    testWidgets('真的走動了就會通知', (tester) async {
      var notifications = 0;
      final c = PetController(
        bounds: const Rect.fromLTWH(0, 0, 1000, 1000),
        brain: _AlwaysIdleBrain(),
        speedPerTick: 10,
        stats: PetStats(initialHunger: 50),
      )..start();
      c.addListener(() => notifications++);

      c.feedAt(const Offset(500, 900));
      await pumpTicks(tester, 5);
      expect(notifications, greaterThanOrEqualTo(5), reason: '每幀都真的移動了一整像素');
      c.dispose();
    });

    testWidgets('暫停時不自主移動，解除後恢復', (tester) async {
      final c = PetController(
        bounds: const Rect.fromLTWH(0, 0, 1000, 1000),
        brain: _AlwaysIdleBrain(),
        speedPerTick: 10,
        stats: PetStats(initialHunger: 50),
      )..start();

      c.feedAt(const Offset(500, 900));
      c.setPaused(true);
      final before = c.position;
      await pumpTicks(tester, 10);
      expect(c.position, before, reason: '選單開著時位置不能被漫遊改掉');

      c.setPaused(false);
      await pumpTicks(tester, 5);
      expect(c.position, isNot(before));
      c.dispose();
    });
  });

  group('PetControllerFactory 換動物保留狀態（A-9a）', () {
    const factory = PetControllerFactory();
    const def = AnimalAnimationDefinition(
      animalId: 'cat',
      displayName: 'Cat',
      frameWidth: 64,
      frameHeight: 64,
      actions: {},
      edgeBehavior: 'walk',
    );

    test('frozen: true 時新 controller 是定格狀態', () {
      final c = factory.create(
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        definition: def,
        stats: PetStats(initialHunger: 50),
        frozen: true,
      );
      expect(c.frozen, isTrue);
      c.dispose();
    });

    test('frozen: false（預設）時新 controller 不是定格', () {
      final c = factory.create(
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        definition: def,
        stats: PetStats(initialHunger: 50),
      );
      expect(c.frozen, isFalse);
      c.dispose();
    });

    test('position 帶入舊位置（clamp 到新 bounds）', () {
      final c = factory.create(
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        definition: def,
        stats: PetStats(initialHunger: 50),
        position: const Offset(500, 500),
      );
      expect(c.position, const Offset(100, 100));
      c.dispose();
    });
  });
}

class _AlwaysIdleBrain implements IPetBrain {
  @override
  PetDecision decideNext(Rect bounds, {bool isHungry = false, double bond = 0}) =>
      const PetDecision(PetBehavior.idle, holdTime: Duration(seconds: 30));
}
