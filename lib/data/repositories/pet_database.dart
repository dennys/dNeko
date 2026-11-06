import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// 全域唯一的 DB 開檔點。
///
/// 兩張表的 DDL 一定要放在這裡：sqflite 依 path 快取已開啟的 DB，
/// 若各 repository 各自 openDatabase，只有第一個 opener 的 onCreate 會跑，
/// 第二張表就永遠不會被建出來。
const String petDbName = 'desktop_pet.db';
const String animalTable = 'animal_resources';
const String settingsTable = 'settings';

/// 2 = 新增 settings 表（既有 v1 安裝由 onUpgrade 補建，資料不動）
const int petDbVersion = 2;

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

Future<Database> openPetDatabase() async {
  final dbPath = join(await getDatabasesPath(), petDbName);
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
  );
}
