import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 全域唯一的 DB 開檔點。
///
/// 兩張表的 DDL 一定要放在這裡：sqflite 依 path 快取已開啟的 DB，
/// 若各 repository 各自 openDatabase，只有第一個 opener 的 onCreate 會跑，
/// 第二張表就永遠不會被建出來。
const String petDbName = 'desktop_pet.db';
const String animalTable = 'animal_resources';
const String settingsTable = 'settings';

/// 2 = 新增 settings 表（既有 v1 安裝由 onUpgrade 補建，資料不動）
/// 3 = 最後一次需要補資料（內建動物）；現在內建由 `AnimalRepository.getAll()` 現拼，
///     加新動物不用再動這裡 —— 也就不用再記得 bump（漏 bump 測試不會紅，舊安裝卻選不到）
const int petDbVersion = 3;

const String _animalDdl = '''
CREATE TABLE $animalTable (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  animal_id        TEXT    NOT NULL UNIQUE,
  display_name     TEXT    NOT NULL,
  local_folder_path TEXT   NOT NULL,
  version          TEXT    NOT NULL,
  is_downloaded    INTEGER NOT NULL DEFAULT 0,
  is_built_in      INTEGER NOT NULL DEFAULT 0,
  updated_at       TEXT    NOT NULL
)
''';

const String _settingsDdl = '''
CREATE TABLE IF NOT EXISTS $settingsTable (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
)
''';

/// 放 DB 的目錄（含桌面後端的切換）。
///
/// Windows 沒有 sqflite 的原生實作（pubspec 的 platforms 只有 Android/iOS/macOS），
/// 所以要換成 FFI 後端；順便換掉資料目錄 —— `getDatabasesPath()` 在 ffi 後端下會退回
/// temp 目錄，重開機資料就沒了（餓度、位置、親密度、下載記錄全丟），這是會咬人的那種錯。
/// Android 那條路一個字都不動。
Future<String> databaseDirectory() async {
  if (Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    return (await getApplicationSupportDirectory()).path;
  }
  return getDatabasesPath();
}

Future<Database> openPetDatabase() async {
  final dbPath = join(await databaseDirectory(), petDbName);
  return openDatabase(
    dbPath,
    version: petDbVersion,
    onCreate: (db, version) async {
      await db.execute(_animalDdl);
      await db.execute(_settingsDdl);
    },
    onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) await db.execute(_settingsDdl);
    },
    // 主 app 與 overlay isolate 各開一條連線寫同一個 DB 檔（餓度、位置、親密度都是 overlay
    // 在寫；主頁每 20 秒讀一次）。預設的 rollback journal 下寫入會互鎖到 SQLITE_BUSY ——
    // overlay 那邊雖然有重試一次，但那是補救，WAL 才是讓「一條寫、一條讀」不互相擋的設定。
    onOpen: (db) => db.execute('PRAGMA journal_mode=WAL'),
  );
}

/// [openPetDatabase] 的快取：**只快取成功的那次**。
///
/// 直接寫 `_db ??= openPetDatabase()` 會連「失敗的 Future」一起存進欄位，之後每次呼叫都
/// 拿到同一顆炸彈直到程序結束 —— 位置與餓度再也存不進去、下載過的動物永久畫佔位圓，
/// 而開檔失敗多半只是暫時的（兩條連線撞鎖、開機搶檔）。失敗時清掉欄位讓下次重試；
/// 同時到來的兩個呼叫仍然共用同一個開檔動作（那才是当初要快取 Future 的理由）。
class DatabaseHandle {
  DatabaseHandle([Future<Database> Function()? open]) : _open = open ?? openPetDatabase;

  final Future<Database> Function() _open;
  Future<Database>? _pending;

  Future<Database> get database => _pending ??= _open().then(
        (db) => db,
        onError: (Object e, StackTrace st) {
          _pending = null; // 失敗不留快取（見類別註解）
          return Future<Database>.error(e, st);
        },
      );
}
