import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:dneko/data/models/animation_action.dart';
import 'package:dneko/data/models/animation_definition.dart';
import 'package:dneko/domain/i_pet_brain.dart';
import 'package:dneko/domain/pet_behavior.dart';
import 'package:dneko/domain/flourish_scheduler.dart';
import 'package:dneko/domain/pet_decision.dart';
import 'package:dneko/domain/pet_stats.dart';
import 'package:dneko/presentation/controllers/pet_controller.dart';
import 'package:dneko/presentation/controllers/pet_controller_factory.dart';

/// 用 testWidgets 的假時鐘推動 PetController 的 16ms 主迴圈（不必多拉依賴）
void main() {
  const tick = Duration(milliseconds: 16);

  /// 不會自己亂播小動作的排程器。**這些測試幾乎都在數「走了幾幀、通知幾次」**，而預設的
  /// `FlourishScheduler()` 用的是沒 seed 的 `Random()`：pump 300 幀就有約 2% 的機率自己跳出
  /// 一個 hop/wobble/doze，把位置與通知數的斷言吹翻（實測過：平行跑滿載時偶爾紅的就是它）。
  /// 要播動作的測試都是直接叫 `playFlourish`，不靠這個排程器 —— 預設關掉是安全的。
  FlourishScheduler quietFlourish() => FlourishScheduler(chancePerMinute: 0);

  PetController make({
    required Rect bounds,
    double? speedPerTick,
    IPetBrain? brain,
    FlourishScheduler? flourish,
  }) {
    final controller = PetController(
      bounds: bounds,
      speedPerTick: speedPerTick,
      brain: brain,
      stats: PetStats(initialHunger: 50),
      flourish: flourish ?? quietFlourish(),
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
        flourish: quietFlourish(),
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
        flourish: quietFlourish(),
      )..start();
      var notifications = 0;
      c.addListener(() => notifications++);

      c.pet();
      expect(c.action, AnimationAction.affectionate);
      expect(notifications, 1);
      c.dispose();
    });

    testWidgets('定格時摸牠有效，撒嬌後回到原動作並維持定格', (tester) async {
      final c = PetController(
        bounds: const Rect.fromLTWH(0, 0, 1000, 1000),
        brain: _AlwaysIdleBrain(),
        stats: PetStats(initialHunger: 50),
        flourish: quietFlourish(),
      )..start();

      c.setFrozen(true);
      final before = c.action;
      // 定格中摸牠也算有效（會加親密度）：撒嬌時動作才會變，撒嬌播完回到原動作、仍定格
      expect(c.pet(), isTrue);
      expect(c.action, AnimationAction.affectionate);
      await tester.pump(const Duration(milliseconds: 1400));
      expect(c.action, before);
      expect(c.frozen, isTrue);

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

  group('選單小動作（flourish）', () {
    testWidgets('playFlourish 會切到對應動作', (tester) async {
      final c = make(
        bounds: const Rect.fromLTWH(0, 0, 1000, 1000),
        brain: _AlwaysIdleBrain(),
      );
      c.playFlourish(PetBehavior.lookAround);
      expect(c.action, AnimationAction.lookAround);
      c.dispose();
    });

    testWidgets('定格時按動作格：解除定格並播出該動作', (tester) async {
      // 2026-11-17 人類的決定：選單那 6 格不該因為定格而變灰 —— 按選單是明確的互動，
      // 跟餵食一樣把定格解開再播（以前是靜默丟掉，選單在定格時等於殘廢一半）。
      final c = make(
        bounds: const Rect.fromLTWH(0, 0, 1000, 1000),
        brain: _AlwaysIdleBrain(),
      );
      c.setFrozen(true);

      c.playFlourish(PetBehavior.lookAround);

      expect(c.action, AnimationAction.lookAround, reason: '定格中按下去也要有反應');
      expect(c.frozen, isFalse, reason: '按動作格會解除定格（與 feedAt 同一套語意）');
      c.dispose();
    });

    testWidgets('定格時撫摸仍維持定格：撒嬌播完回到原動作、不解凍', (tester) async {
      // 摸牠與按動作格不同：摸一下不算「我要開始動了」，所以**不**解除定格。
      final c = make(
        bounds: const Rect.fromLTWH(0, 0, 1000, 1000),
        brain: _AlwaysIdleBrain(),
      );
      c.setFrozen(true);
      final before = c.action;

      expect(c.pet(), isTrue);
      expect(c.action, AnimationAction.affectionate);
      await pumpTicks(tester, 90); // 撒嬌 1200ms
      expect(c.action, before);
      expect(c.frozen, isTrue);
      c.dispose();
    });
  });

  group('PetController 定格與主迴圈開關', () {
    testWidgets('計時動作播到一半被定格：倒數完回到坐著，不會卡在最後一幀', (tester) async {
      // 以前 `_tickFrozenPet` 只倒數撒嬌，「正在跳跳／吃東西時被定格」就永遠停在那一幀。
      final c = make(
        bounds: const Rect.fromLTWH(0, 0, 1000, 1000),
        brain: _AlwaysIdleBrain(),
      );
      c.playFlourish(PetBehavior.hop); // 跳跳 900ms
      expect(c.action, AnimationAction.hop);

      c.setFrozen(true); // 跳跳還沒播完就被定格
      await pumpTicks(tester, 70); // 900ms + 一幀緩衝

      expect(c.action, AnimationAction.sit, reason: '定格中也要把計時動作倒數完');
      expect(c.frozen, isTrue, reason: '倒數完不等於解凍');
      c.dispose();
    });

    testWidgets('stop() 真的停下來，start() 又會走（重開懸浮要靠這對）', (tester) async {
      // 插件的 closeOverlay 只 stopService、不銷毀 cached engine：isolate 會一直活著。
      // driver 發現平台拒絕搬視窗時呼叫 stop()，重開懸浮時由 restart() 呼叫 start()。
      final c = make(
        bounds: const Rect.fromLTWH(0, 0, 1000, 1000),
        speedPerTick: 10,
      )..feedAt(const Offset(500, 900));

      await pumpTicks(tester, 5);
      final at = c.position;
      expect(at, isNot(c.bounds.center));

      c.stop();
      await pumpTicks(tester, 20);
      expect(c.position, at, reason: '定時器還跳著就會繼續走 —— 那正是「關掉後寵物還在散步」的成因');

      c.start();
      await pumpTicks(tester, 5);
      expect(c.position, isNot(at), reason: 'start() 要能把牠喚回來（start 是冪等的）');
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

    group('餓昏鬧騰', () {
      // 預設門檻 60 → 餓昏線 84，95 分穩穩在餓昏區
      PetController starving({IPetBrain? brain}) => PetController(
            bounds: const Rect.fromLTWH(0, 0, 1000, 1000),
            brain: brain ?? _AlwaysIdleBrain(),
            stats: PetStats(initialHunger: 95),
            flourish: quietFlourish(),
          )..start();

      testWidgets('摸牠播討食而不是撒嬌（餓到這樣還撒嬌會被讀成不餓）', (tester) async {
        final c = starving();
        expect(c.stats.isStarving, isTrue);
        expect(c.pet(), isTrue);
        expect(c.action, AnimationAction.beg);
        c.dispose();
      });

      testWidgets('討食播完不接跳跳（跳跳會把「牠餓到在拜」的氣氛破掉）', (tester) async {
        final c = starving();
        c.pet();
        expect(c.action, AnimationAction.beg);
        await tester.pump(const Duration(milliseconds: 5200)); // 超過 _begHold(5s)
        expect(c.action, isNot(AnimationAction.hop));
        c.dispose();
      });

      testWidgets('討食／裝死一鬧就是 5 秒（一秒就收會被讀成抽动，不像在討食）', (tester) async {
        for (final behavior in [PetBehavior.beg, PetBehavior.faint]) {
          final c = starving();
          c.playFlourish(behavior);
          final expected =
              behavior == PetBehavior.beg ? AnimationAction.beg : AnimationAction.faint;
          await tester.pump(const Duration(seconds: 3)); // 還在鬧
          expect(c.action, expected, reason: '$behavior 3 秒就結束了');
          await tester.pump(const Duration(milliseconds: 2200)); // 超過 5s
          expect(c.action, isNot(expected), reason: '$behavior 超過 hold 還停在同一格');
          c.dispose();
        }
      });

      testWidgets('摸、選單、brain 三條路都會觸發 onHungerCry（叫聲只掛一個地方）', (tester) async {
        final cried = <PetBehavior>[];

        final touched = starving()..onHungerCry = cried.add;
        touched.pet(); // 餓昏時摸牠 → 進 beg
        expect(cried, [PetBehavior.beg]);
        touched.dispose();

        final fromMenu = starving()..onHungerCry = cried.add;
        fromMenu.playFlourish(PetBehavior.faint);
        expect(cried, [PetBehavior.beg, PetBehavior.faint]);
        fromMenu.dispose();

        final fromBrain = starving(brain: _RecordingBrain(PetBehavior.beg))
          ..onHungerCry = cried.add;
        fromBrain.beginDrag();
        fromBrain.endDrag(); // brain 自己鬧的這條最容易漏
        expect(cried.last, PetBehavior.beg);
        fromBrain.dispose();
      });

      testWidgets('不餓昏的動作不會觸發 onHungerCry（撒嬌/跳跳不該聽起來在討食）', (tester) async {
        final cried = <PetBehavior>[];
        final c = PetController(
          bounds: const Rect.fromLTWH(0, 0, 1000, 1000),
          brain: _AlwaysIdleBrain(),
          stats: PetStats(initialHunger: 5),
          flourish: quietFlourish(),
        )
          ..start()
          ..onHungerCry = cried.add;
        c.pet();
        c.playFlourish(PetBehavior.hop);
        c.playFlourish(PetBehavior.doze);
        expect(cried, isEmpty);
        c.dispose();
      });

      testWidgets('不餓時摸牠照樣撒嬌＋跳跳（餓昏判斷不誤傷）', (tester) async {
        final c = PetController(
          bounds: const Rect.fromLTWH(0, 0, 1000, 1000),
          brain: _AlwaysIdleBrain(),
          stats: PetStats(initialHunger: 5),
          flourish: quietFlourish(),
        )..start();
        expect(c.pet(), isTrue);
        expect(c.action, AnimationAction.affectionate);
        await tester.pump(const Duration(milliseconds: 1300)); // 撒嬌 hold 1200 後接跳跳
        expect(c.action, AnimationAction.hop);
        c.dispose();
      });

      testWidgets('選單那兩格定格中也按得下去，播完不會卡在最後一幀', (tester) async {
        final c = starving();
        c.setFrozen(true);
        c.playFlourish(PetBehavior.faint);
        expect(c.action, AnimationAction.faint);
        expect(c.frozen, isFalse, reason: '按選單是明確互動，跟餵食一樣先解定格');
        await tester.pump(const Duration(milliseconds: 5200)); // 超過 _faintHold(5s)
        expect(c.action, isNot(AnimationAction.faint));
        c.dispose();
      });

      testWidgets('brain 傳到 isStarving（餓昏決策鏈路接得起來）', (tester) async {
        final brain = _RecordingBrain();
        final c = starving(brain: brain);
        c.beginDrag();
        c.endDrag(); // endDrag 一定請 brain 決定下一個行為
        expect(brain.lastIsHungry, isTrue);
        expect(brain.lastIsStarving, isTrue);
        c.dispose();

        final calm = _RecordingBrain();
        final c2 = PetController(
          bounds: const Rect.fromLTWH(0, 0, 1000, 1000),
          brain: calm,
          stats: PetStats(initialHunger: 10),
          flourish: quietFlourish(),
        )..start();
        c2.beginDrag();
        c2.endDrag();
        expect(calm.lastIsStarving, isFalse);
        c2.dispose();
      });

      testWidgets('brain 決定 beg/faint 時用自己的幀，不會掉進預設的 sit', (tester) async {
        for (final pair in [
          (PetBehavior.beg, AnimationAction.beg),
          (PetBehavior.faint, AnimationAction.faint),
          (PetBehavior.wobble, AnimationAction.wobble),
        ]) {
          final c = starving(brain: _RecordingBrain(pair.$1));
          c.beginDrag();
          c.endDrag();
          expect(c.action, pair.$2, reason: '${pair.$1} 的動作不該被 _applyDecision 預設吃掉');
          c.dispose();
        }
      });
    });
  });
}

class _AlwaysIdleBrain implements IPetBrain {
  @override
  PetDecision decideNext(
    Rect bounds, {
    bool isHungry = false,
    bool isStarving = false,
    double bond = 0,
  }) =>
      const PetDecision(PetBehavior.idle, holdTime: Duration(seconds: 30));
}

/// 記下 controller 傳進來的飢餓狀態，並固定回一個行為（驗證決策鏈路用）。
class _RecordingBrain implements IPetBrain {
  _RecordingBrain([this.forced = PetBehavior.idle]);

  final PetBehavior forced;
  bool? lastIsHungry;
  bool? lastIsStarving;

  @override
  PetDecision decideNext(
    Rect bounds, {
    bool isHungry = false,
    bool isStarving = false,
    double bond = 0,
  }) {
    lastIsHungry = isHungry;
    lastIsStarving = isStarving;
    return PetDecision(forced);
  }
}
