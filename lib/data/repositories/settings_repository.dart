import 'dart:convert';
import 'dart:ui';

import 'package:sqflite/sqflite.dart';

import '../../domain/pet_bond.dart';
import '../../domain/pet_stats.dart';
import '../../domain/pet_settings.dart';
import 'pet_database.dart';

/// 存盤的餓度、它的時間點，以及「收起來那一刻牠是不是正在螢幕上跑」。
///
/// [wasDisplayed] 是「收起來的寵物不餓」這條規則的實作（人類的決定）：
/// * `false` = 正常收起來（關掉懸浮、或換成別的寵物）→ 重開時**不補算**缺席餓度；
/// * `true`  = 當掉／被系統殺掉（沒來得關）→ 依 [savedAt] 補算，跟舊版一樣。
/// 舊資料沒有這個欄位時一律當 `true`（維持升級前的行為，不懲罰舊安裝）。
typedef HungerRecord = ({double hunger, DateTime savedAt, bool wasDisplayed});

/// 醒來時該用的餓度。**抽成純函式是因為這條規則值得被測試鎖住**
/// （「收起來不餓」寫在呼叫端的話，改了沒人會紅）。
double hungerOnWake(HungerRecord? saved, DateTime now) {
  if (saved == null) return 0; // 沒資料 = 沒養過這隻 → 飽的出場（人類的決定）
  if (!saved.wasDisplayed) return saved.hunger; // 正常收起來 → 凍結，不餓
  return PetStats.hungerAfterAbsence(saved.hunger, now.difference(saved.savedAt));
}

/// 只負責：PetSettings 與寵物飢餓值在 settings(KV) 表的讀寫
class SettingsRepository {
  static const _settingsKey = 'pet_settings';

  // ===== 每隻動物各一份的狀態（人類的決定：「各養各的」）=====
  //
  // 這三個字串是**on-disk 格式**，改等於資料搬家，要連遷移一起想。做成 public static 不是
  // 為了美，是為了讓測試能鎖住它們（`test/pet_state_per_animal_test.dart`）。
  //
  // 只有「這隻是誰養的」相關的是 per-animal：餓度、位置、親密度。
  // 大小／速度／活動範圍／語系／主題是**全域偏好**，不做各養各的（人類的決定）。
  static String hungerKey(String animalId) => 'pet_hunger_$animalId';
  static String positionKey(String animalId) => 'pet_position_$animalId';
  static String bondKey(String animalId) => 'pet_bond_$animalId';

  /// v1 的全域鍵（那時八隻共用一份餓度與位置）。遷移後**保留不讀**，出事可回退。
  static const _legacyHungerKey = 'pet_hunger';
  static const _legacyPositionKey = 'pet_position';

  /// 遷移做過就寫這個鍵，避免每次都去碰舊鍵（也避免搬一半時重複搬）。
  static const _migratedKey = 'pet_state_migrated_v2';

  /// 開檔只快取成功的那次（見 [DatabaseHandle]）；與 AnimalRepository 同一套。
  final DatabaseHandle _handle = DatabaseHandle();

  Future<Database> get _database => _handle.database;

  /// 設定檔損毀或还没存過時回預設值，不讓 app 開不起來
  Future<PetSettings> load() async {
    final row = await _row(_settingsKey);
    if (row == null) return const PetSettings();
    try {
      final decoded = jsonDecode(row);
      if (decoded is! Map) return const PetSettings();
      return PetSettings.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return const PetSettings();
    }
  }

  Future<void> save(PetSettings settings) =>
      _put(_settingsKey, jsonEncode(settings.toJson()));

  /// 沒存過回 null（讓呼叫端決定預設，而不是在這裡猜）
  Future<HungerRecord?> loadHunger(String animalId) async {
    await _migrateFromLegacyOnce();
    return decodeHunger(await _row(hungerKey(animalId)));
  }

  /// 寫餓度。[wasDisplayed] 的意義見 [HungerRecord]；正常運行的每次存盤都是 `true`，
  /// 「收起來」那條路要走 [stow]（或明確傳 `false`）。
  Future<void> saveHunger(String animalId, double hunger,
          {bool wasDisplayed = true, DateTime? at}) async {
    await _migrateFromLegacyOnce();
    await _put(hungerKey(animalId), encodeHunger(hunger, at ?? DateTime.now(), wasDisplayed: wasDisplayed));
  }

  /// 「收起來」：關掉懸浮、或換成別的寵物時呼叫 —— 把當前餓度留檔並標成「不在螢幕上」，
  /// 之後的時間就不算牠餓著（人類的決定：收起來的寵物不餓）。
  ///
  /// 餓度由呼叫端給（只有 overlay 那側的 `PetController` 知道當下幾點）；給 null 就只翻旗標、
  /// 保留目前存的那個值（主 app 關懸浮時只能走這條，它看不到宠物的即時餓度）。
  Future<void> stow(String animalId, {double? hunger}) async {
    await _migrateFromLegacyOnce();
    final key = hungerKey(animalId);
    final current = decodeHunger(await _row(key));
    final value = hunger ?? current?.hunger ?? 0;
    await _put(key, encodeHunger(value, DateTime.now(), wasDisplayed: false));
  }

  /// 懸浮視窗上次關閉時的左上角座標；沒存過或格式壞掉回 null
  Future<Offset?> loadPosition(String animalId) async {
    await _migrateFromLegacyOnce();
    final raw = await _row(positionKey(animalId));
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final x = (decoded['x'] as num?)?.toDouble();
      final y = (decoded['y'] as num?)?.toDouble();
      return x == null || y == null ? null : Offset(x, y);
    } catch (_) {
      return null;
    }
  }

  Future<void> savePosition(String animalId, Offset position) async {
    await _migrateFromLegacyOnce();
    await _put(
      positionKey(animalId),
      jsonEncode({'x': position.dx, 'y': position.dy}),
    );
  }

  /// 親密度：沒存過或格式壞掉回 null（呼叫端決定預設 —— 目前預設是「從 0 開始算」）
  Future<PetBond?> loadBond(String animalId) async =>
      PetBond.decode(await _row(bondKey(animalId)));

  Future<void> saveBond(String animalId, PetBond bond) =>
      _put(bondKey(animalId), bond.encode());

  /// 動物被刪掉時把它那三把鍵（親密度／餓度／位置）一起清掉。
  /// 不清就永久留垃圾；id 之後被別隻下載動物重用時還會憑空繼承前一個主人的分數與餓度。
  Future<void> deletePetState(String animalId) async {
    final db = await _database;
    await db.delete(
      settingsTable,
      where: 'key = ?',
      whereArgs: [bondKey(animalId)],
    );
    await db.delete(
      settingsTable,
      where: 'key = ? OR key = ?',
      whereArgs: [hungerKey(animalId), positionKey(animalId)],
    );
  }

  /// 餓度要連「什麼時候存的」一起存：懸浮沒開時沒有 tick，重開時得依缺席時間補算餓度。
  ///
  /// 舊版只存一個裸小數（`'42.00'`），那種資料無從得知是何時寫的 —— 就當作剛剛寫的、
  /// 不追溯補算（否則升級當下會被一次補到餓透，像被懲罰）。餵一次就回到正常軌道。
  static HungerRecord? decodeHunger(String? raw) {
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final hunger = (decoded['hunger'] as num?)?.toDouble();
        if (hunger == null) return null;
        final at = (decoded['at'] as num?)?.toInt();
        return (
          hunger: hunger,
          savedAt: DateTime.fromMillisecondsSinceEpoch(
            at ?? DateTime.now().millisecondsSinceEpoch,
          ),
          wasDisplayed: (decoded['shown'] as num?)?.toInt() != 0,
        );
      }
    } catch (_) {
      // 不是 JSON → 當成舊格式再試一次
    }
    final legacy = double.tryParse(raw);
    return legacy == null
        ? null
        : (hunger: legacy, savedAt: DateTime.now(), wasDisplayed: true);
  }

  /// 舊格式（沒有 `shown`）讀成 `true`：那是「還在跑的時候存的」，維持升級前會補算的行為。
  static String encodeHunger(double hunger, DateTime at, {bool wasDisplayed = true}) => jsonEncode({
        'hunger': double.parse(hunger.toStringAsFixed(2)),
        'at': at.millisecondsSinceEpoch,
        'shown': wasDisplayed ? 1 : 0,
      });

  Future<String?> _row(String key) async {
    final db = await _database;
    final rows = await db.query(settingsTable, where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  /// 遷移：把 v1 那份全域餓度/位置搬給「當時選中的那隻」，然後寫一個完成標記。
  ///
  /// 只在**本 isolate 第一次碰 per-animal 狀態時**跑一次；失敗時要清掉記號讓下次重試
  /// （跟 [DatabaseHandle] 同一個教訓：失敗的 Future 不能留在欄位上毒化整個程序）。
  /// 舊鍵**保留不刪** —— 遷移出錯時還有東西可以回退。
  Future<void>? _migration;

  Future<void> _migrateFromLegacyOnce() async {
    final pending = _migration;
    if (pending != null) {
      await pending; // 同一個失敗會被每個等待者各拿一次，這是預期的
      return;
    }
    final future = _migrateFromLegacy();
    _migration = future;
    try {
      await future;
    } catch (_) {
      _migration = null; // 失敗不留在欄位上，下次呼叫會重試
      rethrow;
    }
  }

  Future<void> _migrateFromLegacy() async {
    final selected = (await load()).animalId; // 搬給「當前那隻」
    if (await _row(_migratedKey) != null) return;
    final legacyHunger = await _row(_legacyHungerKey);
    final legacyPosition = await _row(_legacyPositionKey);
    if (legacyHunger != null && await _row(hungerKey(selected)) == null) {
      await _put(hungerKey(selected), legacyHunger);
    }
    if (legacyPosition != null && await _row(positionKey(selected)) == null) {
      await _put(positionKey(selected), legacyPosition);
    }
    await _put(_migratedKey, DateTime.now().millisecondsSinceEpoch.toString());
  }

  Future<void> _put(String key, String value) async {
    final db = await _database;
    await db.insert(
      settingsTable,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
