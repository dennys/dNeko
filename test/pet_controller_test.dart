import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:dneko/data/models/animation_action.dart';
import 'package:dneko/domain/i_pet_brain.dart';
import 'package:dneko/domain/pet_behavior.dart';
import 'package:dneko/domain/pet_decision.dart';
import 'package:dneko/domain/pet_stats.dart';
import 'package:dneko/presentation/controllers/pet_controller.dart';

/// 用 testWidgets 的假時鐘推動 PetController 的 16ms 主迴圈（不必多拉依賴）
void main() {
  const tick = Duration(milliseconds: 16);

  PetController make({
    required Rect bounds,
    double? speedPerTick,
  }) {
    final controller = PetController(
      bounds: bounds,
      speedPerTick: speedPerTick,
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

    testWidgets('updateBounds 之後拖曳會被夾在新範圍內', (tester) async {
      final c = make(bounds: const Rect.fromLTWH(0, 0, 1000, 1000));
      c.updateBounds(const Rect.fromLTWH(300, 700, 100, 100));
      c.beginDrag();
      c.dragTo(const Offset(-500, -500));

      expect(c.bounds, const Rect.fromLTWH(300, 700, 100, 100));
      expect(c.position, const Offset(300, 700));
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
      // pet() 只換動作、不動位置，而 hold=2s 讓接下來的 125 幀都提前 return；
      // 少了 _enter 的通知，按下去之後兩秒內畫面完全不會重繪。
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
}

class _AlwaysIdleBrain implements IPetBrain {
  @override
  PetDecision decideNext(Rect bounds, {bool isHungry = false}) =>
      const PetDecision(PetBehavior.idle, holdTime: Duration(seconds: 30));
}
