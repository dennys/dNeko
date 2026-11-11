import 'package:dneko/domain/drag_watch.dart';
import 'package:flutter_test/flutter_test.dart';

/// 把 [n] 次同一個座標餵進去，回報每一步。
List<DragStep> feed(DragWatch w, Offset p, int n) =>
    List.generate(n, (_) => w.step(p));

void main() {
  const still = Offset(120, 340);

  group('DragWatch —— 沒拖就是沒拖', () {
    // REVIEW #2 的回歸點：舊實作拿 PetController.position 當基準，而寵物每 16ms 就在走
    // （brain 45% 的決定是 wander）→ 在走動的寵物身上摸一下就被判成拖曳，先卡 0.4 秒、
    // 撒嬌動畫被 wander/idle 蓋掉。基準換成「視窗自己第一次的讀值」之後，
    // 視窗不動 ⇒ 無論寵物走多快都必須一路 keepWaiting 到 stop，一次 drag 都不能有。
    test('視窗都不動（＝單純點擊，寵物在旁邊走也一樣）→ 不準進入拖曳', () {
      final w = DragWatch();

      final steps = feed(w, still, 8);

      expect(steps, List.filled(7, DragStep.keepWaiting) + [DragStep.stop]);
      expect(w.dragging, isFalse);
    });

    test('在門檻內抖來抖去也不算拖曳', () {
      final w = DragWatch();

      final steps = [
        for (var i = 0; i < 8; i++)
          w.step(Offset(still.dx + (i.isEven ? 0 : 1), still.dy)),
      ];

      expect(steps, isNot(contains(DragStep.startDrag)));
      expect(steps.last, DragStep.stop);
    });

    test('400ms（8 次）內沒動就自己停，不必等使用者放手', () {
      final w = DragWatch(maxPreDragPolls: 3);

      expect(feed(w, still, 2), [DragStep.keepWaiting, DragStep.keepWaiting]);
      expect(w.step(still), DragStep.stop);
    });
  });

  group('DragWatch —— 真的在拖', () {
    test('視窗離開錨點 → startDrag，之後每一步都要同步座標', () {
      final w = DragWatch();
      expect(w.step(still), DragStep.keepWaiting);

      final moved = const Offset(130, 340);
      expect(w.step(moved), DragStep.startDrag);
      expect(w.dragging, isTrue);
      expect(w.step(const Offset(140, 340)), DragStep.dragging);
    });

    test('慢拖（每跳 3px）也偵測得到；門檻以下的微動不算', () {
      final slow = DragWatch();
      expect(slow.step(still), DragStep.keepWaiting);
      expect(slow.step(const Offset(123, 340)), DragStep.startDrag);

      final creeping = DragWatch();
      creeping.step(still);
      expect(creeping.step(const Offset(121, 340)), DragStep.keepWaiting);
    });

    test('拖到定住 8 次 → stop（放手），之後不再回報 dragging', () {
      final w = DragWatch();
      w.step(still);
      expect(w.step(const Offset(200, 300)), DragStep.startDrag);

      final steps = feed(w, const Offset(200, 300), 8);

      expect(steps, List.filled(7, DragStep.dragging) + [DragStep.stop]);
      expect(w.dragging, isFalse);
    });

    test('拖曳中偶爾停一拍又繼續動 → 不會被靜止計數誤殺', () {
      final w = DragWatch();
      w.step(still);
      w.step(const Offset(200, 300));

      feed(w, const Offset(200, 300), 5); // 停 5 拍（未達 8）
      expect(w.step(const Offset(210, 300)), DragStep.dragging);
      expect(feed(w, const Offset(210, 300), 8).last, DragStep.stop,
          reason: '靜止計數要從 0 重數，不能接上剛才那 5 拍');
    });
  });

  group('DragWatch —— 傳入 expected（app 目前放視窗的位置）', () {
    // overlay 的實際用法：driver 每 tick 都在搬視窗，視窗會比 controller 慢一拍。
    test('寵物走動、視窗跟著走（落後一拍）→ 不準判成拖曳', () {
      final w = DragWatch(moveThresholdPx: 16);
      var appPos = still;
      var windowPos = still;
      final steps = <DragStep>[];
      for (var i = 0; i < 20; i++) {
        windowPos = appPos; // 上一拍的座標
        appPos = appPos + const Offset(5, 0); // 每 50ms 走 5px
        steps.add(w.step(windowPos, expected: appPos));
      }

      expect(steps, isNot(contains(DragStep.startDrag)));
    });

    test('視窗被手拖走、app 座標沒動 → 超過門檻就 startDrag', () {
      final w = DragWatch(moveThresholdPx: 16);

      expect(w.step(const Offset(130, 340), expected: still), DragStep.keepWaiting);
      expect(w.step(const Offset(150, 340), expected: still), DragStep.startDrag);
    });
  });

  group('DragWatch —— 門檻可調', () {
    test('moveThresholdPx 放大後，同樣的位移就不算拖曳', () {
      final w = DragWatch(moveThresholdPx: 20);
      w.step(still);

      expect(w.step(const Offset(130, 340)), DragStep.keepWaiting);
    });
  });
}
