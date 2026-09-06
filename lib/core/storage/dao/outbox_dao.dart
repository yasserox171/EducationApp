import 'package:sqflite/sqflite.dart';

import '../../../data/models/enums.dart';
import '../../../data/models/outbox_op.dart';
import '../app_database.dart';

/// طابور الإرسال: العمليات التي تنتظر الاتصال بالإنترنت.
class OutboxDao {
  OutboxDao(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  /// يضيف عملية. إن كان لها `dedupKey` تُحذف العمليات المعلّقة التي تحمل
  /// نفس المفتاح — التحديث الأحدث يكفي (مثال: تقدّم نفس الدرس).
  Future<void> enqueue(OutboxOp op) async {
    await _db.transaction((txn) async {
      final key = op.dedupKey;
      if (key != null) {
        await txn.delete(
          'outbox',
          where: 'dedup_key = ? AND status = ?',
          whereArgs: [key, OutboxStatus.pending.wire],
        );
      }
      await txn.insert(
        'outbox',
        op.toDbRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// العمليات الجاهزة للإرسال الآن، بالترتيب الزمني.
  Future<List<OutboxOp>> readyOps({int limit = 50}) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await _db.query(
      'outbox',
      where: 'status = ? AND next_attempt_at <= ?',
      whereArgs: [OutboxStatus.pending.wire, now],
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map(OutboxOp.fromDbRow).toList(growable: false);
  }

  Future<int> pendingCount() async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM outbox WHERE status = ?',
      [OutboxStatus.pending.wire],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> failedCount() async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM outbox WHERE status = ?',
      [OutboxStatus.failed.wire],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> remove(String id) =>
      _db.delete('outbox', where: 'id = ?', whereArgs: [id]);

  Future<void> update(OutboxOp op) => _db.insert(
        'outbox',
        op.toDbRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<List<OutboxOp>> failedOps() async {
    final rows = await _db.query(
      'outbox',
      where: 'status = ?',
      whereArgs: [OutboxStatus.failed.wire],
      orderBy: 'created_at ASC',
    );
    return rows.map(OutboxOp.fromDbRow).toList(growable: false);
  }

  /// إعادة جدولة كل العمليات الفاشلة (زر «إعادة المحاولة» في الإعدادات).
  Future<void> retryAllFailed() async {
    final ops = await failedOps();
    if (ops.isEmpty) return;
    await _db.transaction((txn) async {
      for (final op in ops) {
        await txn.insert(
          'outbox',
          op.retryNow().toDbRow(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> clear() => _db.delete('outbox');
}
