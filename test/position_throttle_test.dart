import 'package:dneko/domain/position_throttle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime.utc(2026, 11, 11, 12);
  DateTime later(int seconds) => t0.add(Duration(seconds: seconds));

  group('PositionThrottle', () {
    test('還沒有基準點 → 第一次一定要存（否則位置永遠不會被記下來）', () {
      expect(PositionThrottle().shouldSave(const Offset(10, 10), t0), isTrue);
    });

    test('靜止的寵物一筆都不寫（idle／sleep／凍結時每 16ms 仍會 notify）', () {
      final t = PositionThrottle()..didSave(const Offset(100, 100), t0);

      for (var s = 1; s <= 600; s++) {
        expect(t.shouldSave(const Offset(100, 100), later(s)), isFalse,
            reason: '位置完全沒動就不該寫盤，第 $s 秒也是');
      }
    });

    test('移動不足門檻就不寫，就算已經隔了很久', () {
      final t = PositionThrottle()..didSave(const Offset(100, 100), t0);

      expect(t.shouldSave(const Offset(120, 100), later(600)), isFalse);
    });

    test('隔不夠久也不寫，就算已經移動很多', () {
      final t = PositionThrottle()..didSave(const Offset(100, 100), t0);

      expect(t.shouldSave(const Offset(900, 900), later(2)), isFalse);
    });

    test('夠久又夠遠 → 寫；寫完同一個位置不再重複寫', () {
      final t = PositionThrottle()..didSave(const Offset(100, 100), t0);
      final next = const Offset(400, 100);

      expect(t.shouldSave(next, later(5)), isTrue);
      t.didSave(next, later(5));
      expect(t.shouldSave(next, later(30)), isFalse, reason: '位置沒變，沒有再寫一次的理由');
    });

    test('慢走的寵物：距離基準要一路累積，不能每拍重設', () {
      // 10 px/s（速度下限）：每 5 秒只有 50px，剛剛好卡在門檻上 —— 若把基準設成「上一次
      // 問過的 position」而不是「上一次真的存過的 position」，牠就永遠存不進去。
      final t = PositionThrottle()..didSave(const Offset(0, 0), t0);
      for (var s = 1; s < 5; s++) {
        expect(t.shouldSave(Offset(s * 10.0, 0), later(s)), isFalse);
      }

      expect(t.shouldSave(const Offset(50, 0), later(5)), isTrue);
    });

    test('didSave 之後時間與基準位置一起重設（只更新其中一個就會失準）', () {
      final t = PositionThrottle()..didSave(const Offset(0, 0), t0);

      // 先問一次不寫（時間不夠），再讓時間夠：此時距離要還是從 (0,0) 算起
      expect(t.shouldSave(const Offset(80, 0), later(4)), isFalse);
      expect(t.shouldSave(const Offset(80, 0), later(6)), isTrue);

      t.didSave(const Offset(80, 0), later(6));
      // 新的基準在 (80,0)：走 30px 又不夠遠了（若基準沒更新，這裡會誤判成該寫）
      expect(t.shouldSave(const Offset(110, 0), later(12)), isFalse);
      expect(t.shouldSave(const Offset(200, 0), later(12)), isTrue);
    });

    test('門檻與間隔可調', () {
      final t = PositionThrottle(minMovePx: 200, interval: const Duration(minutes: 1))
        ..didSave(Offset.zero, t0);

      expect(t.shouldSave(const Offset(100, 0), later(120)), isFalse);
      expect(t.shouldSave(const Offset(300, 0), later(120)), isTrue);
    });
  });
}
