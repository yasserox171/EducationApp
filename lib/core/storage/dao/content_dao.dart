import 'package:sqflite/sqflite.dart';

import '../../../data/models/enums.dart';
import '../../../data/models/lesson.dart';
import '../../../data/models/lesson_block.dart';
import '../../../data/models/subject.dart';
import '../app_database.dart';

/// قراءة/كتابة المحتوى المخزَّن محليًا: المواد، الدروس، الفقرات.
class ContentDao {
  ContentDao(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  // ------------------------------------------------------------- المواد

  Future<List<Subject>> getSubjects() async {
    final rows = await _db.query('subjects', orderBy: 'position ASC, title ASC');
    return rows.map(Subject.fromDbRow).toList(growable: false);
  }

  Future<Subject?> getSubject(String id) async {
    final rows = await _db.query(
      'subjects',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Subject.fromDbRow(rows.first);
  }

  /// يستبدل قائمة المواد بالكامل بما ورد من الخادم (مصدر الحقيقة).
  Future<void> replaceSubjects(List<Subject> subjects) async {
    await _db.transaction((txn) async {
      await txn.delete('subjects');
      for (final subject in subjects) {
        await txn.insert(
          'subjects',
          subject.toDbRow(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> upsertSubject(Subject subject) => _db.insert(
        'subjects',
        subject.toDbRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<void> deleteSubject(String id) async {
    await _db.transaction((txn) async {
      final lessonRows = await txn.query(
        'lessons',
        columns: ['id'],
        where: 'subject_id = ?',
        whereArgs: [id],
      );
      final lessonIds =
          lessonRows.map((row) => row['id']! as String).toList(growable: false);
      for (final lessonId in lessonIds) {
        await txn.delete('blocks', where: 'lesson_id = ?', whereArgs: [lessonId]);
        await txn
            .delete('media_files', where: 'lesson_id = ?', whereArgs: [lessonId]);
        await txn.delete(
          'lesson_downloads',
          where: 'lesson_id = ?',
          whereArgs: [lessonId],
        );
      }
      await txn.delete('lessons', where: 'subject_id = ?', whereArgs: [id]);
      await txn.delete('subjects', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ------------------------------------------------------------- الدروس

  Future<List<Lesson>> getLessons({
    required String subjectId,
    LessonLevel? level,
    bool publishedOnly = false,
  }) async {
    final where = StringBuffer('subject_id = ?');
    final args = <Object?>[subjectId];
    if (level != null) {
      where.write(' AND level = ?');
      args.add(level.wire);
    }
    if (publishedOnly) {
      where.write(' AND is_published = 1');
    }
    final rows = await _db.query(
      'lessons',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'position ASC, title ASC',
    );
    return rows.map(Lesson.fromDbRow).toList(growable: false);
  }

  Future<Lesson?> getLesson(String id) async {
    final rows = await _db.query(
      'lessons',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Lesson.fromDbRow(rows.first);
  }

  /// يستبدل دروس مادة معيّنة بما ورد من الخادم، مع الحفاظ على
  /// `blocks_cached_at` للدروس التي ما زالت موجودة.
  Future<void> replaceLessonsOfSubject(
    String subjectId,
    List<Lesson> lessons,
  ) async {
    await _db.transaction((txn) async {
      final existing = await txn.query(
        'lessons',
        columns: ['id', 'blocks_cached_at'],
        where: 'subject_id = ?',
        whereArgs: [subjectId],
      );
      final cachedAt = <String, String?>{
        for (final row in existing)
          row['id']! as String: row['blocks_cached_at'] as String?,
      };
      final incomingIds = lessons.map((e) => e.id).toSet();

      for (final id in cachedAt.keys) {
        if (!incomingIds.contains(id)) {
          await txn.delete('blocks', where: 'lesson_id = ?', whereArgs: [id]);
          await txn
              .delete('media_files', where: 'lesson_id = ?', whereArgs: [id]);
          await txn.delete(
            'lesson_downloads',
            where: 'lesson_id = ?',
            whereArgs: [id],
          );
        }
      }
      await txn.delete('lessons', where: 'subject_id = ?', whereArgs: [subjectId]);

      for (final lesson in lessons) {
        final row = lesson.toDbRow();
        row['blocks_cached_at'] = cachedAt[lesson.id];
        await txn.insert(
          'lessons',
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> upsertLesson(Lesson lesson) async {
    final existing = await _db.query(
      'lessons',
      columns: ['blocks_cached_at'],
      where: 'id = ?',
      whereArgs: [lesson.id],
      limit: 1,
    );
    final row = lesson.toDbRow();
    if (existing.isNotEmpty) {
      row['blocks_cached_at'] = existing.first['blocks_cached_at'];
    }
    await _db.insert(
      'lessons',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteLesson(String id) async {
    await _db.transaction((txn) async {
      await txn.delete('blocks', where: 'lesson_id = ?', whereArgs: [id]);
      await txn.delete('media_files', where: 'lesson_id = ?', whereArgs: [id]);
      await txn.delete('lesson_downloads', where: 'lesson_id = ?', whereArgs: [id]);
      await txn.delete('lessons', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// إعادة ترتيب الدروس محليًا بعد سحب/إفلات في واجهة الأستاذ.
  Future<void> applyLessonOrder(List<String> orderedIds) async {
    await _db.transaction((txn) async {
      for (var i = 0; i < orderedIds.length; i++) {
        await txn.update(
          'lessons',
          {'position': i},
          where: 'id = ?',
          whereArgs: [orderedIds[i]],
        );
      }
    });
  }

  // ------------------------------------------------------------ الفقرات

  Future<List<LessonBlock>> getBlocks(String lessonId) async {
    final rows = await _db.query(
      'blocks',
      where: 'lesson_id = ?',
      whereArgs: [lessonId],
      orderBy: 'position ASC',
    );
    return rows.map(LessonBlock.fromDbRow).toList(growable: false);
  }

  Future<void> replaceBlocks(String lessonId, List<LessonBlock> blocks) async {
    await _db.transaction((txn) async {
      await txn.delete('blocks', where: 'lesson_id = ?', whereArgs: [lessonId]);
      for (final block in blocks) {
        await txn.insert(
          'blocks',
          block.toDbRow(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await txn.update(
        'lessons',
        {
          'blocks_cached_at': DateTime.now().toUtc().toIso8601String(),
          'blocks_count': blocks.length,
        },
        where: 'id = ?',
        whereArgs: [lessonId],
      );
    });
  }

  /// هل فقرات الدرس مخزَّنة محليًا؟ (شرط العمل بدون إنترنت)
  Future<bool> hasBlocks(String lessonId) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM blocks WHERE lesson_id = ?',
      [lessonId],
    );
    return (Sqflite.firstIntValue(result) ?? 0) > 0;
  }

  Future<DateTime?> blocksCachedAt(String lessonId) async {
    final rows = await _db.query(
      'lessons',
      columns: ['blocks_cached_at'],
      where: 'id = ?',
      whereArgs: [lessonId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DateTime.tryParse(rows.first['blocks_cached_at'] as String? ?? '');
  }
}
