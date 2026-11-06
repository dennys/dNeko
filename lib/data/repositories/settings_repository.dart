import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../domain/pet_settings.dart';
import 'pet_database.dart';

/// 只負責：PetSettings 與寵物飢餓值在 settings(KV) 表的讀寫
class SettingsRepository {
  static const _settingsKey = 'pet_settings';
  static const _hungerKey = 'pet_hunger';

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
  Future<double?> loadHunger() async {
    final row = await _row(_hungerKey);
    return row == null ? null : double.tryParse(row);
  }

  Future<void> saveHunger(double hunger) =>
      _put(_hungerKey, hunger.toStringAsFixed(2));

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
