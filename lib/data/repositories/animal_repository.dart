import 'package:sqflite/sqflite.dart';
import 'i_animal_repository.dart';
import '../models/animal_resource.dart';
import 'pet_database.dart';

class AnimalRepository implements IAnimalRepository {
  static const _tableName = animalTable;

  Database? _db;

  Future<Database> get _database async => _db ??= await openPetDatabase();

  @override
  Future<List<AnimalResource>> getAll() async {
    final db = await _database;
    final rows = await db.query(_tableName, orderBy: 'display_name ASC');
    return rows.map(AnimalResource.fromMap).toList();
  }

  @override
  Future<List<AnimalResource>> getDownloaded() async {
    final db = await _database;
    final rows = await db.query(
      _tableName,
      where: 'is_downloaded = 1',
      orderBy: 'display_name ASC',
    );
    return rows.map(AnimalResource.fromMap).toList();
  }

  @override
  Future<AnimalResource?> getById(String animalId) async {
    final db = await _database;
    final rows = await db.query(
      _tableName,
      where: 'animal_id = ?',
      whereArgs: [animalId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AnimalResource.fromMap(rows.first);
  }

  @override
  Future<void> upsert(AnimalResource resource) async {
    final db = await _database;
    await db.insert(
      _tableName,
      resource.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> delete(String animalId) async {
    final db = await _database;
    await db.delete(_tableName, where: 'animal_id = ?', whereArgs: [animalId]);
  }

  /// 內建動物（素材就在 `assets/animals/<id>/`）的**唯一**定義處。
  ///
  /// 之前拆成兩處而且互相矛盾：這裡只塞 cat、名字還寫成日文 `'ねこ'`（全 app 只有這一行是日文），
  /// 而 `overlay_main` 那邊又自己硬編 `cat => 小花貓 / dog => 小柴犬`。後果不只是名字不一致：
  /// 素材資料夾裡明明有 dog，DB 卻沒有這一列，於是主頁的動物選單（讀 `getAll()`）
  /// 永遠看不到小柴犬 —— 素材有、動畫有、程式也支援，使用者卻永遠選不到牠。
  /// ⚠️ 註冊＝「素材齊了」。只放 animation.json 還沒圖的動物不准進這裡
  /// （`test/asset_frames_test.dart` 會擋），否則主頁選得到、overlay 只能畫佔位圓。
  /// 待補：`('dog', '小柴犬')` —— 素材目錄 `assets/animals/dog/` 目前只有 animation.json，
  /// 12 張圖還沒產；產圖流程見 `ASSET_PROMPT.md`，產完把上面那列加回來即可。
  static List<AnimalResource> get builtIns => [
        for (final (id, name) in const [('cat', '小花貓')])
          AnimalResource(
            animalId: id,
            displayName: name,
            localFolderPath: '', // 內建走 assets，沒有本地資料夾
            version: '1.0.0',
            isDownloaded: false,
            isBuiltIn: true,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
      ];

  /// 依 id 取內建定義。DB 那一列被使用者刪掉時，overlay 還是能用打包進來的素材把寵物畫出來。
  static AnimalResource? builtIn(String animalId) {
    for (final animal in builtIns) {
      if (animal.animalId == animalId) return animal;
    }
    return null;
  }

  /// 把內建動物塞進 DB，讓主頁選單看得到牠們。重複呼叫是安全的。
  ///
  /// shortcut: 舊安裝已存在的列（cat 顯示名 'ねこ'）不會被蓋掉 —— 那正是 ConflictAlgorithm.ignore
  /// 的原意（不覆蓋使用者自己的資料）。app 還沒對外發布，開發機要重置就清 app 資料。
  Future<void> seedBuiltIns() async {
    final db = await _database;
    for (final animal in builtIns) {
      final row = animal.toMap()
        ..remove('id') // 交給 AUTOINCREMENT
        ..['updated_at'] = DateTime.now().toIso8601String();
      await db.insert(_tableName, row, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }
}
