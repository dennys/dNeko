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

  /// 解析一隻動物該用哪份素材。主 app 的預覽塊與 overlay 都走這裡 —— 兩邊各寫一份
  /// 遲早對不起來（之前這個順序只存在於 `overlay_main._resolveResource`）。
  ///
  /// 順序很重要：先問 DB，讓「下載過/改過」的那份資料贏過過時的內建定義
  /// （之前是內建優先，等於 cat/dog 永遠無視 DB 裡的記錄）。DB 沒有這一列（使用者刪掉了）
  /// 才退回內建 —— 素材是隨 app 打包的，不該因為一列被刪就整個變成佔位圓。
  @override
  Future<AnimalResource?> resolveResource(String animalId) async {
    return await getById(animalId) ?? AnimalRepository.builtIn(animalId);
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
  static List<AnimalResource> get builtIns => [
        for (final (id, name) in const [
          ('cat', '小花貓'),
          ('dog', '小狗'),
          ('penguin', '小企鵝'),
        ])
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

  /// 把内建动物塞进 DB，让主页选菜单看得到它们 —— but only on a fresh install.
  ///
  /// Seeding on every start used to resurrect built-ins the user had deleted
  /// from the store, so the delete silently came back at the next launch.
  /// shortcut: an app update that adds a new built-in animal will not appear for
  /// existing installs; when that happens, seed per-id or bump petDbVersion.
  Future<void> seedBuiltIns() async {
    final db = await _database;
    if ((await db.query(_tableName, limit: 1)).isNotEmpty) return; // user deletes must stick
    for (final animal in builtIns) {
      final row = animal.toMap()
        ..remove('id') // 交給 AUTOINCREMENT
        ..['updated_at'] = DateTime.now().toIso8601String();
      await db.insert(_tableName, row, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }
}
