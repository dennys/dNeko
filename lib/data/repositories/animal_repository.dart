import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'i_animal_repository.dart';
import '../models/animal_resource.dart';

class AnimalRepository implements IAnimalRepository {
  static const _dbName = 'desktop_pet.db';
  static const _tableName = 'animal_resources';

  Database? _db;

  Future<Database> get _database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) => db.execute('''
        CREATE TABLE $_tableName (
          id               INTEGER PRIMARY KEY AUTOINCREMENT,
          animal_id        TEXT    NOT NULL UNIQUE,
          display_name     TEXT    NOT NULL,
          local_folder_path TEXT   NOT NULL,
          version          TEXT    NOT NULL,
          is_downloaded    INTEGER NOT NULL DEFAULT 0,
          is_built_in      INTEGER NOT NULL DEFAULT 0,
          updated_at       TEXT    NOT NULL
        )
      '''),
    );
  }

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

  /// Insert built-in animals so the overlay can load them from assets.
  /// Uses ConflictAlgorithm.ignore so repeated calls are safe.
  Future<void> seedBuiltIns() async {
    final db = await _database;
    const builtIns = [
      {
        'animal_id': 'cat',
        'display_name': 'ねこ',
        'local_folder_path': '',
        'version': '1.0.0',
        'is_downloaded': 0,
        'is_built_in': 1,
      },
    ];
    for (final row in builtIns) {
      await db.insert(
        _tableName,
        {...row, 'updated_at': DateTime.now().toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }
}
