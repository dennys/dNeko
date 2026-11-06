import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:dneko/data/models/animation_action.dart';
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
}
