import 'package:sqflite/sqflite.dart';

import '../../../data/models/download_state.dart';
import '../../../data/models/enums.dart';
import '../app_database.dart';

/// حالة التحميل على الجهاز: درس كامل + كل ملف وسائط.
class DownloadDao {
  DownloadDao(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  // -------------------------------------------------------- تحميل الدرس

  Future<LessonDownload?> getLessonDownload(String lessonId) async {
    final rows = await _db.query(
      'lesson_downloads',
      where: 'lesson_id = ?',
      whereArgs: [lessonId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return LessonDownload.fromDbRow(rows.first);
  }

  Future<Map<String, LessonDownload>> getLessonDownloads(
    List<String> lessonIds,
  ) async {
    if (lessonIds.isEmpty) return const {};
    final placeholders = List.filled(lessonIds.length, '?').join(', ');
    final rows = await _db.query(
      'lesson_downloads',
      where: 'lesson_id IN ($placeholders)',
      whereArgs: lessonIds,
    );
    return {
      for (final row in rows)
        row['lesson_id']! as String: LessonDownload.fromDbRow(row),
    };
  }

  Future<List<LessonDownload>> getCompletedDownloads() async {
    final rows = await _db.query(
      'lesson_downloads',
      where: 'status = ?',
      whereArgs: [DownloadStatus.completed.wire],
      orderBy: 'completed_at DESC',
    );
    return rows.map(LessonDownload.fromDbRow).toList(growable: false);
  }

  Future<void> upsertLessonDownload(LessonDownload download) => _db.insert(
        'lesson_downloads',
        download.toDbRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<void> deleteLessonDownload(String lessonId) async {
    await _db.transaction((txn) async {
      await txn.delete(
        'lesson_downloads',
        where: 'lesson_id = ?',
        whereArgs: [lessonId],
      );
      await txn.delete(
        'media_files',
        where: 'lesson_id = ?',
        whereArgs: [lessonId],
      );
    });
  }

  // --------------------------------------------------------- ملفات الوسائط

  Future<MediaFile?> getMediaFile(String blockId) async {
    final rows = await _db.query(
      'media_files',
      where: 'block_id = ?',
      whereArgs: [blockId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MediaFile.fromDbRow(rows.first);
  }

  Future<List<MediaFile>> getMediaFilesForLesson(String lessonId) async {
    final rows = await _db.query(
      'media_files',
      where: 'lesson_id = ?',
      whereArgs: [lessonId],
    );
    return rows.map(MediaFile.fromDbRow).toList(growable: false);
  }

  Future<void> upsertMediaFile(MediaFile file) => _db.insert(
        'media_files',
        file.toDbRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<void> deleteMediaFilesForLesson(String lessonId) => _db.delete(
        'media_files',
        where: 'lesson_id = ?',
        whereArgs: [lessonId],
      );

  /// إجمالي البايتات المسجَّلة كمحمَّلة (لعرضه في الإعدادات).
  Future<int> totalDownloadedBytes() async {
    final result = await _db.rawQuery(
      "SELECT SUM(bytes_downloaded) AS total FROM media_files WHERE status = 'completed'",
    );
    return (result.first['total'] as int?) ?? 0;
  }

  /// عند الإقلاع: أي تحميل عالق في حالة «جارٍ» يُعاد وسمه كفاشل
  /// (التطبيق أُغلق أثناء التحميل).
  Future<void> resetStaleDownloads() async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.update(
      'lesson_downloads',
      {
        'status': DownloadStatus.failed.wire,
        'error': 'تم إيقاف التحميل عند إغلاق التطبيق',
        'updated_at': now,
      },
      where: 'status IN (?, ?)',
      whereArgs: [DownloadStatus.downloading.wire, DownloadStatus.queued.wire],
    );
    await _db.update(
      'media_files',
      {'status': DownloadStatus.failed.wire, 'updated_at': now},
      where: 'status IN (?, ?)',
      whereArgs: [DownloadStatus.downloading.wire, DownloadStatus.queued.wire],
    );
  }
}
