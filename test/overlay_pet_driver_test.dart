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

  /// false = 平台拒絕這次搬動（懸浮視窗已經不存在）。用它來測 driver 會不會停掉寵物。
  bool accepts = true;

  @override
  Future<bool> moveTo(Offset position) async {
    inFlight++;
    maxInFlight = inFlight > maxInFlight ? inFlight : maxInFlight;
    moves.add(position);
    await gate?.future;
    inFlight--;
    return accepts;
  }

  @override
  Future<bool> resize({required double width, required double height}) async => true;
  @override
  Future<Offset> currentPosition() async => moves.isEmpty ? Offset.zero : moves.last;
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

      controller.syncFromWindow(const Offset(50, 60)); // 觸發 notifyListeners
      await pumpEventQueue();

      expect(window.moves, isNotEmpty);
      expect(window.moves.last, const Offset(50, 60));
    });

    test('停用時不移動視窗', () async {
      final controller = PetController(bounds: bounds);
      final window = _FakeWindow();
      final driver = OverlayPetDriver(controller, window);

      driver.setEnabled(false);
      controller.syncFromWindow(const Offset(30, 30));
      await pumpEventQueue();

      expect(window.moves, isEmpty);
    });

    // 平台呼叫是 async 的，而 controller 每 16ms notify 一次。之前是 unawaited 發出，
    // 於是一串 moveTo 在通道上排隊、視窗永遠慢幾幀；現在串行送，並記住期間的最新位置。
    test('moveTo 還在飛時不會再送第二個，但最後位置一定会送到', () async {
      final controller = PetController(bounds: bounds);
      final window = _FakeWindow()..gate = Completer<void>();
      OverlayPetDriver(controller, window);

      controller.syncFromWindow(const Offset(100, 100)); // (100,100)
      await pumpEventQueue();
      expect(window.moves, [const Offset(100, 100)]);

      // 第一個呼叫還卡在 gate 上，這段時間連續拖 10 次
      for (var i = 1; i <= 10; i++) {
        controller.syncFromWindow(Offset(100.0 + i, 100.0 + i));
      }
      await pumpEventQueue();
      expect(window.inFlight, 1, reason: '同一時間只能有一個 moveTo 在飛');

      window.gate!.complete();
      await pumpEventQueue();

      expect(window.maxInFlight, 1);
      expect(window.moves.last, const Offset(110, 110), reason: '拖曳期間的位置不能遺失');
    });

    // 插件的 closeOverlay 只有 stopService，onDestroy 不銷毀 cached engine：
    // 關掉懸浮之後這個 isolate 還活著。平台那側這時不擲例外、只回 false，
    // 所以一定要收那個 bool，否則就是 60Hz 沒人收的通道呼叫 + 每 5 秒寫一筆位置，
    // 而且全程無聲（真機實測：關掉後寵物繼續走，下次開懸浮牠出現在別的地方）。
    test('平台連續拒絕搬視窗 → 認定視窗已不在，停掉寵物主迴圈', () async {
      final controller = PetController(bounds: bounds);
      final window = _FakeWindow()..accepts = false;
      OverlayPetDriver(controller, window);

      for (var i = 1; i <= 4; i++) {
        controller.syncFromWindow(Offset(10.0 * i, 10.0 * i));
        await pumpEventQueue();
      }
      final sent = window.moves.length;
      expect(sent, greaterThan(0), reason: '前幾次還是要送（1 次就停太衝動）');

      controller.syncFromWindow(const Offset(300, 300));
      await pumpEventQueue();

      expect(window.moves.length, sent, reason: '停下來之後就不該再送沒人收的呼叫');
      controller.dispose();
    });

    // 收起來的寵物不餓（人類的決定）：driver 發現視窗已不在 = 懸浮被關掉的那一刻，
    // 呼叫端要趁這時把餓度標成「不在螢幕上」。這條沒接上的話，下次開懸浮會被補算成餓昏。
    test('停機那一刻回呼 onStopped（用它把餓度標成收起來）', () async {
      var stowed = 0;
      final controller = PetController(bounds: bounds);
      final window = _FakeWindow()..accepts = false;
      OverlayPetDriver(controller, window, onStopped: () => stowed++);

      for (var i = 1; i <= 5; i++) {
        controller.syncFromWindow(Offset(10.0 * i, 10.0 * i));
        await pumpEventQueue();
      }
      expect(stowed, 1, reason: '只回呼一次，不是每次被拒絕都喊一次');

      controller.syncFromWindow(const Offset(300, 300));
      await pumpEventQueue();
      expect(stowed, 1, reason: '已經停了就不該重複回呼');
      controller.dispose();
    });

    test('onStopped 丟例外不影響停機（存盤壞了不能把 driver 拖下水）', () async {
      final controller = PetController(bounds: bounds);
      final window = _FakeWindow()..accepts = false;
      OverlayPetDriver(controller, window, onStopped: () => throw StateError('DB 寫不進去'));

      for (var i = 1; i <= 5; i++) {
        controller.syncFromWindow(Offset(10.0 * i, 10.0 * i));
        await pumpEventQueue();
      }
      final sent = window.moves.length;
      controller.syncFromWindow(const Offset(300, 300));
      await pumpEventQueue();
      expect(window.moves.length, sent, reason: '回呼壞了也要照樣停機');
      controller.dispose();
    });

    test('restart() 之後又會跟著搬（重開懸浮靠這個醒過來）', () async {
      final controller = PetController(bounds: bounds);
      final window = _FakeWindow()..accepts = false;
      final driver = OverlayPetDriver(controller, window);

      for (var i = 1; i <= 4; i++) {
        controller.syncFromWindow(Offset(10.0 * i, 10.0 * i));
        await pumpEventQueue();
      }
      expect(controller.position, const Offset(40, 40));

      window.accepts = true;
      driver.restart();
      await pumpEventQueue();

      expect(window.moves.last, const Offset(40, 40), reason: '重開時要立刻把視窗對齊寵物');
      controller.dispose();
    });

    // 「失敗要有 log」以前沒有測試保護過：它就從 appError（tag dneko.error）漂到 print
    // （tag flutter），而除錯時用的是 `adb logcat -s dneko.error` —— 那條等於不存在。
    test('moveTo 失敗要留一條 log（而且不能每 16ms 洗一行）', () async {
      final logs = <String>[];
      final controller = PetController(bounds: bounds);
      final window = _ThrowingWindow();
      OverlayPetDriver(controller, window, log: (m, e, st) => logs.add(m));

      controller.syncFromWindow(const Offset(100, 100));
      await pumpEventQueue();
      controller.syncFromWindow(const Offset(120, 130));
      await pumpEventQueue();

      expect(logs, hasLength(1), reason: '要留痕，但每 tick 一行會把 logcat 洗爆');
      controller.dispose();
    });

    test('因為平台一直拒絕而停下主迴圈時，要有一條說得清發生什麼的 log', () async {
      final logs = <String>[];
      final controller = PetController(bounds: bounds);
      final window = _FakeWindow()..accepts = false;
      OverlayPetDriver(controller, window, log: (m, e, st) => logs.add(m));

      for (var i = 1; i <= 5; i++) {
        controller.syncFromWindow(Offset(10.0 * i, 10.0 * i));
        await pumpEventQueue();
      }

      expect(logs.join('\n'), contains('懸浮視窗已不存在'),
          reason: '這是「關掉懸浮後 isolate 還在跑」唯一的可見訊號');
      controller.dispose();
    });

    test('moveTo 失敗時記得起來，下次變動會重試', () async {
      final controller = PetController(bounds: bounds);
      final window = _ThrowingWindow();
      OverlayPetDriver(controller, window);

      controller.syncFromWindow(const Offset(100, 100));
      await pumpEventQueue();
      expect(window.attempts, 1);

      controller.syncFromWindow(const Offset(120, 130));
      await pumpEventQueue();
      expect(window.attempts, greaterThan(1), reason: '失敗後不能永久卡在舊位置');
    });
  });
}

class _ThrowingWindow implements IOverlayWindow {
  int attempts = 0;

  @override
  Future<bool> moveTo(Offset position) async {
    attempts++;
    throw Exception('platform rejected');
  }

  @override
  Future<bool> resize({required double width, required double height}) async => true;
  @override
  Future<Offset> currentPosition() async => Offset.zero;
  @override
  Future<void> close() async {}
}
