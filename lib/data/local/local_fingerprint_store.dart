import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'fingerprint_entry.dart';

class LocalFingerprintStore {
  LocalFingerprintStore._();

  static final instance = LocalFingerprintStore._();

  Database? _database;

  Future<void> initialize() async {
    if (_database != null) return;
    final databasePath = await getDatabasesPath();
    _database = await openDatabase(
      path.join(databasePath, 'originchain.db'),
      version: 2,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE local_fingerprints (
            sha256 TEXT PRIMARY KEY,
            file_name TEXT NOT NULL,
            size_bytes INTEGER NOT NULL,
            created_at_utc TEXT NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE preferences (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await database.execute('''
            CREATE TABLE preferences (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
        }
      },
    );
  }

  Future<void> save(FingerprintEntry entry) async {
    final database = _requireDatabase();
    await database.insert(
      'local_fingerprints',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<FingerprintEntry?> latest() async {
    final rows = await _requireDatabase().query(
      'local_fingerprints',
      orderBy: 'created_at_utc DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return FingerprintEntry.fromMap(rows.first);
  }

  Future<String?> preference(String key) async {
    final rows = await _requireDatabase().query(
      'preferences',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value']! as String;
  }

  Future<void> savePreference(String key, String value) async {
    await _requireDatabase().insert('preferences', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Database _requireDatabase() {
    final database = _database;
    if (database == null) {
      throw StateError('LocalFingerprintStore.initialize() must run first.');
    }
    return database;
  }
}
