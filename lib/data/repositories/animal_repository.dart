import 'package:sqflite/sqflite.dart';
import 'i_animal_repository.dart';
import '../models/animal_resource.dart';
import 'pet_database.dart';

class AnimalRepository implements IAnimalRepository {
  static const _tableName = animalTable;

  Database? _db;

  Future<Database> get _database async => _db ??= await openPetDatabase();

  /// 選單與商店看的的清單 = DB 列 ∪ [builtIns]（同 id 以 DB 為準）。
  ///
  /// 內建動物不靠「seed 進 DB」才選得到：那套要求「註冊 builtIns ＋ pubspec assets ＋
  /// bump petDbVersion」三件事一起做，而 bump 那件沒有任何測試擋 —— 漏掉時 analyze 綠、
  /// 測試全過，舊安裝的選單卻永遠看不到新動物（c616eab 加四隻就踩過）。
  /// 副作用：「把內建從 DB 刪掉就不會再長回來」這個語意沒了。目前 UI 沒有刪內建的路徑
  /// （`remove()` 只給商店下載的動物用）；真要做，得另記一列「使用者隱藏」標記。
  @override
  Future<List<AnimalResource>> getAll() async {
    final db = await _database;
    final rows = await db.query(_tableName);
    return mergeBuiltIns(rows.map(AnimalResource.fromMap).toList(), builtIns);
  }

  /// DB 列與內建定義的合併（純函式，[getAll] 與測試共用）：同 id 時 DB 那份贏
  /// （下載過/改過的資料比較新），依 display_name 排序。
  static List<AnimalResource> mergeBuiltIns(
    List<AnimalResource> dbRows,
    List<AnimalResource> builtIns,
  ) {
    final byId = <String, AnimalResource>{for (final a in builtIns) a.animalId: a};
    for (final a in dbRows) {
      byId[a.animalId] = a;
    }
    return byId.values.toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
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
          ('cat2', '阿咪'),
          ('dog', '小狗'),
          ('penguin', '小企鵝'),
          ('heart_dog', '愛心狗'),
          ('racoon', '浣熊'),
          ('sloth', '樹懶'),
          ('monkey', '猴子'),
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

}
