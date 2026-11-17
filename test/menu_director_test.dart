import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:dneko/presentation/controllers/menu_director.dart';

/// 假的依賴：把「凍結／解凍／關視窗／派工」都記成一串事件，
/// 這樣「兩邊一定要配成對、而且順序不能反」這種事就能直接斷言。
class _FakeMenu {
  final events = <String>[];

  /// 最近一次排進來的逾時（測試自己叫它，不必真的等 6 秒）
  void Function()? pendingClose;

  MenuDirector director() => MenuDirector(
        timeout: const Duration(seconds: 6),
        onPause: () => events.add('pause'),
        onResume: () => events.add('resume'),
        onHideWindow: () async => events.add('hide'),
        onAction: (action) => events.add('action:$action'),
        scheduleClose: (close) {
          pendingClose = close;
          return Timer(const Duration(days: 1), () {}); // 真的不等，由 pendingClose 觸發
        },
      );
}

Future<void> _openOk(_FakeMenu h, MenuDirector d) async {
  await d.open(() async => h.events.add('showWindow'));
}

void main() {
  group('MenuDirector 開／關', () {
    test('開成功：凍住寵物、isOpen 變 true、排了逾時', () async {
      final h = _FakeMenu();
      final d = h.director();

      expect(await d.open(() async {}), isTrue);

      expect(d.isOpen, isTrue);
      expect(h.events, ['pause']);
      expect(h.pendingClose, isNotNull, reason: '開成功才該排 6 秒自動關');
    });

    test('開到一半失敗：**一定要把寵物解凍**，並把例外丟回給呼叫端', () async {
      // 這條就是以前的 bug：setPaused(true) 之後才 await currentPosition()，
      // 那一步丟例外時解凍被 `if (!_menuOpen) return` 擋掉 → 寵物永久凍住，
      // 而 engine 是 cached 的，關掉重開也不救。
      final h = _FakeMenu();
      final d = h.director();

      await expectLater(
        d.open(() async => throw StateError('讀不到視窗位置')),
        throwsStateError,
      );

      expect(d.isOpen, isFalse);
      expect(h.events, ['pause', 'resume', 'hide'], reason: 'pause 之後不管成功失敗都要有 resume');
      expect(h.pendingClose, isNull, reason: '沒開成就不該留一個會自己亂關的定時器');
    });

    test('close() 冪等：連按兩次只還原一次', () async {
      final h = _FakeMenu();
      final d = h.director();
      await _openOk(h, d);

      await d.close();
      await d.close();

      expect(h.events.where((e) => e == 'resume').length, 1);
      expect(d.isOpen, isFalse);
    });

    test('沒開過就 close()：不會憑空 resume，但仍請原生關視窗', () async {
      final h = _FakeMenu();
      final d = h.director();

      await d.close();

      expect(h.events, ['hide']);
    });

    test('開著的時候再 open() 一次不會重複凍住', () async {
      final h = _FakeMenu();
      final d = h.director();
      await _openOk(h, d);

      expect(await d.open(() async {}), isFalse);
      expect(h.events.where((e) => e == 'pause').length, 1);
    });

    test('逾時到點就自己收掉（使用者沒在看了只有定時器抓得到）', () async {
      final h = _FakeMenu();
      final d = h.director();
      await _openOk(h, d);

      h.pendingClose!();
      await pumpEventQueue();

      expect(d.isOpen, isFalse);
      expect(h.events, ['pause', 'showWindow', 'resume', 'hide']);
    });

    test('abort()：收定時器與視窗，但不碰寵物（它跟著一起沒了）', () async {
      final h = _FakeMenu();
      final d = h.director();
      await _openOk(h, d);

      d.abort();
      await pumpEventQueue();

      expect(h.events.contains('resume'), isFalse);
      expect(h.events.last, 'hide');
      expect(d.isOpen, isFalse);
    });
    // 換動物（_loadAnimal 叫 abort()）常常就發生在選單還請原生開出來的路上。
    // 不擋住就會留一張舊動物的選單在畫面上六秒，而它每一格點了都沒反應。
    test('open() 進行中被 abort()：幽靈選單要自己收掉，不排逾時', () async {
      final h = _FakeMenu();
      final d = h.director();
      final shown = Completer<void>();

      final opened = d.open(() => shown.future.then((_) => h.events.add('showWindow')));
      await pumpEventQueue(); // 讓 open() 走到 await showWindow()

      d.abort();
      shown.complete();

      expect(await opened, isFalse, reason: '被超車的這場等於沒開成');
      expect(d.isOpen, isFalse);
      expect(h.pendingClose, isNull, reason: '不該留一個會自己亂關的定時器');
      expect(h.events.where((e) => e == 'hide').length, 2, reason: 'abort 一次、幽靈選單再收一次');
      expect(h.events.contains('resume'), isFalse, reason: 'abort 已清掉凍結，不能再憑空 resume');
    });
  });

  group('MenuDirector 指令派工', () {
    test('按到動作：先解凍再派工（順序反了 circle 會被暫停擋掉）', () async {
      final h = _FakeMenu();
      final d = h.director();
      await _openOk(h, d);

      d.onCommand('{"action":"feed"}');
      await pumpEventQueue();

      expect(h.events, ['pause', 'showWindow', 'resume', 'hide', 'action:feed']);
    });

    test('interact 只重新計時，不關選單也不派工', () async {
      final h = _FakeMenu();
      final d = h.director();
      await _openOk(h, d);
      final first = h.pendingClose;

      d.onCommand('{"action":"interact"}');
      await pumpEventQueue();

      expect(d.isOpen, isTrue);
      expect(h.events.contains('resume'), isFalse);
      expect(h.events.any((e) => e.startsWith('action:')), isFalse);
      expect(h.pendingClose, isNot(same(first)), reason: '有在按就要重新排 6 秒');
    });

    test('選單已經收掉之後才遲到的指令一律丟掉', () async {
      final h = _FakeMenu();
      final d = h.director();
      await _openOk(h, d);
      await d.close();
      final after = List.of(h.events);

      d.onCommand('{"action":"feed"}');
      d.onCommand('{"action":"interact"}');
      await pumpEventQueue();

      expect(h.events, after, reason: '逾時／點外面已經先收了，遲到的指令不該再動寵物');
    });

    test('指令內容壞掉就丟掉，不能讓選單把寵物弄壞', () {
      final h = _FakeMenu();
      final d = h.director();
      for (final bad in [null, 42, '不是 JSON', '[1,2]', '{}', '{"action":7}']) {
        expect(() => d.onCommand(bad), returnsNormally);
        expect(MenuDirector.actionOf(bad), isNull, reason: '$bad');
      }
    });
  });
}
