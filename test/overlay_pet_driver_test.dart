import 'dart:async';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:dneko/domain/i_overlay_window.dart';
import 'package:dneko/presentation/controllers/pet_controller.dart';
import 'package:dneko/presentation/controllers/overlay_pet_driver.dart';

/// 測試替身：記錄被移動到哪裡
class _FakeWindow implements IOverlayWindow {
  final List<Offset> moves = [];

  /// 不為 null 時，moveTo 會卡在這裡等待 —— 用來驗證「同一時間只有一個平台呼叫在飛」。
  Completer<void>? gate;
  int inFlight = 0;
  int maxInFlight = 0;

  @override
  Future<void> moveTo(Offset position) async {
    inFlight++;
    maxInFlight = inFlight > maxInFlight ? inFlight : maxInFlight;
    moves.add(position);
    await gate?.future;
    inFlight--;
  }

  @override
  Future<void> resize({required double width, required double height}) async {}
  @override
  Future<void> close() async {}
}

void main() {
  const bounds = Rect.fromLTWH(0, 0, 200, 200);

  group('OverlayPetDriver', () {
    test('位置變化時移動視窗', () async {
      final controller = PetController(bounds: bounds);
      final window = _FakeWindow();
      OverlayPetDriver(controller, window);

      controller.beginDrag();
      controller.dragTo(const Offset(50, 60)); // 觸發 notifyListeners
      await pumpEventQueue();

      expect(window.moves, isNotEmpty);
      expect(window.moves.last, const Offset(50, 60));
    });

    test('停用時不移動視窗', () async {
      final controller = PetController(bounds: bounds);
      final window = _FakeWindow();
      final driver = OverlayPetDriver(controller, window);

      driver.setEnabled(false);
      controller.dragTo(const Offset(30, 30));
      await pumpEventQueue();

      expect(window.moves, isEmpty);
    });

    // 平台呼叫是 async 的，而 controller 每 16ms notify 一次。之前是 unawaited 發出，
    // 於是一串 moveTo 在通道上排隊、視窗永遠慢幾幀；現在串行送，並記住期間的最新位置。
    test('moveTo 還在飛時不會再送第二個，但最後位置一定会送到', () async {
      final controller = PetController(bounds: bounds);
      final window = _FakeWindow()..gate = Completer<void>();
      OverlayPetDriver(controller, window);

      controller.beginDrag(); // (100,100)
      await pumpEventQueue();
      expect(window.moves, [const Offset(100, 100)]);

      // 第一個呼叫還卡在 gate 上，這段時間連續拖 10 次
      for (var i = 1; i <= 10; i++) {
        controller.dragTo(Offset(100.0 + i, 100.0 + i));
      }
      await pumpEventQueue();
      expect(window.inFlight, 1, reason: '同一時間只能有一個 moveTo 在飛');

      window.gate!.complete();
      await pumpEventQueue();

      expect(window.maxInFlight, 1);
      expect(window.moves.last, const Offset(110, 110), reason: '拖曳期間的位置不能遺失');
    });

    test('moveTo 失敗時記得起來，下次變動會重試', () async {
      final controller = PetController(bounds: bounds);
      final window = _ThrowingWindow();
      OverlayPetDriver(controller, window);

      controller.beginDrag();
      await pumpEventQueue();
      expect(window.attempts, 1);

      controller.dragTo(const Offset(120, 130));
      await pumpEventQueue();
      expect(window.attempts, greaterThan(1), reason: '失敗後不能永久卡在舊位置');
    });
  });
}

class _ThrowingWindow implements IOverlayWindow {
  int attempts = 0;

  @override
  Future<void> moveTo(Offset position) async {
    attempts++;
    throw Exception('platform rejected');
  }

  @override
  Future<void> resize({required double width, required double height}) async {}
  @override
  Future<void> close() async {}
}
