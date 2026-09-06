import 'package:sqflite/sqflite.dart';

import '../app_database.dart';

/// قيم صغيرة غير حسّاسة: أوقات آخر مزامنة، أعلام الواجهة… إلخ.
/// (المعلومات الحسّاسة تذهب إلى `SecureStore` لا هنا.)
class KvDao {
  KvDao(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  static const String lastContentSyncAt = 'last_content_sync_at';
  static const String lastProgressSyncAt = 'last_progress_sync_at';

  Future<String?> get(String key) async {
    final rows = await _db.query(
      'kv',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> set(String key, String value) => _db.insert(
        'kv',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<DateTime?> getDateTime(String key) async {
    final raw = await get(key);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> setDateTime(String key, DateTime value) =>
      set(key, value.toUtc().toIso8601String());

  Future<void> remove(String key) =>
      _db.delete('kv', where: 'key = ?', whereArgs: [key]);
}
