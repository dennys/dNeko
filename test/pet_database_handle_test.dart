import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:dneko/data/repositories/pet_database.dart';

/// 只為了拿到一個能放進 `Future<Database>` 的物件：本檔測的是**快取策略**，
/// 不碰任何 SQL，所以全部成員都交給 noSuchMethod（真被呼叫就會炸，剛好是我們不想要的）。
class _FakeDb implements Database {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('DatabaseHandle 開檔快取', () {
    test('同時到來的兩個呼叫共用同一個開檔動作', () async {
      var opens = 0;
      final handle = DatabaseHandle(() async {
        opens++;
        return _FakeDb();
      });

      final both = await Future.wait([handle.database, handle.database]);

      expect(opens, 1);
      expect(identical(both[0], both[1]), isTrue);
    });

    test('開檔成功之後不再重開', () async {
      var opens = 0;
      final handle = DatabaseHandle(() async {
        opens++;
        return _FakeDb();
      });

      await handle.database;
      await handle.database;

      expect(opens, 1);
    });

    // 這條鎖住的是 `_db ??= openPetDatabase()` 那一版的 bug：失敗的 Future 被存進欄位，
    // 之後每次呼叫都拿到同一顆炸彈，於是整個程序再也存不到位置/餓度、下載過的動物永久
    // 畫佔位圓。開檔失敗多半是暫時的（兩條連線撞鎖），所以必須留給下次重試。
    test('開檔失敗不留快取：下次呼叫會重試（不是帶著炸彈活一整個程序）', () async {
      var opens = 0;
      final handle = DatabaseHandle(() async {
        opens++;
        if (opens == 1) throw StateError('SQLITE_BUSY');
        return _FakeDb();
      });

      await expectLater(handle.database, throwsStateError);

      expect(await handle.database, isA<_FakeDb>());
      expect(opens, 2);
    });

    test('失敗期間同時到來的呼叫仍共用同一次開檔（不會一人重開一次）', () async {
      var opens = 0;
      final handle = DatabaseHandle(() async {
        opens++;
        throw StateError('開不了檔');
      });

      final first = handle.database;
      final second = handle.database;
      await expectLater(first, throwsStateError);
      await expectLater(second, throwsStateError);

      expect(opens, 1);
    });
  });
}
