import 'dart:convert';
import 'dart:ui';

import 'package:sqflite/sqflite.dart';

import '../../domain/pet_bond.dart';
import '../../domain/pet_settings.dart';
import 'pet_database.dart';

/// 存盤的餓度與它的時間點（缺席補算要用時間點）。
typedef HungerRecord = ({double hunger, DateTime savedAt});

/// 只負責：PetSettings 與寵物飢餓值在 settings(KV) 表的讀寫
class SettingsRepository {
  static const _settingsKey = 'pet_settings';
  static const _hungerKey = 'pet_hunger';
  static const _positionKey = 'pet_position';
  /// 親密度**每隻動物各一份**（人類的決定：「這隻是我養的」與「我對貓好」語意不同）
  static String _bondKey(String animalId) => 'pet_bond_$animalId';

  Database? _db;

  Future<Database> get _database async => _db ??= await openPetDatabase();

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
  Future<HungerRecord?> loadHunger() async => decodeHunger(await _row(_hungerKey));

  Future<void> saveHunger(double hunger, {DateTime? at}) =>
      _put(_hungerKey, encodeHunger(hunger, at ?? DateTime.now()));

  /// 懸浮視窗上次關閉時的左上角座標；沒存過或格式壞掉回 null
  Future<Offset?> loadPosition() async {
    final raw = await _row(_positionKey);
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

  Future<void> savePosition(Offset position) => _put(
        _positionKey,
        jsonEncode({'x': position.dx, 'y': position.dy}),
      );

  /// 親密度：沒存過或格式壞掉回 null（呼叫端決定預設 —— 目前預設是「從 0 開始算」）
  Future<PetBond?> loadBond(String animalId) async =>
      PetBond.decode(await _row(_bondKey(animalId)));

  Future<void> saveBond(String animalId, PetBond bond) =>
      _put(_bondKey(animalId), bond.encode());

  /// 動物被刪掉時清掉它那列親密度（不清就永久留垃圾；id 之後被別隻下載動物重用時
  /// 還會憑空繼承前一個主人的分數）
  Future<void> deleteBond(String animalId) async {
    final db = await _database;
    await db.delete(settingsTable, where: 'key = ?', whereArgs: [_bondKey(animalId)]);
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
        );
      }
    } catch (_) {
      // 不是 JSON → 當成舊格式再試一次
    }
    final legacy = double.tryParse(raw);
    return legacy == null ? null : (hunger: legacy, savedAt: DateTime.now());
  }

  static String encodeHunger(double hunger, DateTime at) => jsonEncode({
        'hunger': double.parse(hunger.toStringAsFixed(2)),
        'at': at.millisecondsSinceEpoch,
      });

  Future<String?> _row(String key) async {
    final db = await _database;
    final rows = await db.query(settingsTable, where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
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
