import 'package:sqflite/sqflite.dart';

import '../../../data/models/enums.dart';
import '../../../data/models/progress.dart';
import '../app_database.dart';

/// تقدّم التلميذ، محاولات الكويز، ومستوى كل مادة — كلها تُكتب محليًا أولًا.
class ProgressDao {
  ProgressDao(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  // ------------------------------------------------------------ التقدّم

  Future<LessonProgress?> getProgress(String lessonId) async {
    final rows = await _db.query(
      'lesson_progress',
      where: 'lesson_id = ?',
      whereArgs: [lessonId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return LessonProgress.fromDbRow(rows.first);
  }

  Future<Map<String, LessonProgress>> getProgressForSubject(
    String subjectId,
  ) async {
    final rows = await _db.query(
      'lesson_progress',
      where: 'subject_id = ?',
      whereArgs: [subjectId],
    );
    return {
      for (final row in rows)
        row['lesson_id']! as String: LessonProgress.fromDbRow(row),
    };
  }

  Future<List<LessonProgress>> getAllProgress() async {
    final rows = await _db.query('lesson_progress');
    return rows.map(LessonProgress.fromDbRow).toList(growable: false);
  }

  Future<void> upsertProgress(LessonProgress progress) => _db.insert(
        'lesson_progress',
        progress.toDbRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  /// دمج تقدّم قادم من الخادم: الأحدث يفوز، والتغييرات المحلية غير المرسلة
  /// لا تُدهس.
  Future<void> mergeRemoteProgress(List<LessonProgress> remote) async {
    await _db.transaction((txn) async {
      for (final item in remote) {
        final existing = await txn.query(
          'lesson_progress',
          where: 'lesson_id = ?',
          whereArgs: [item.lessonId],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          final local = LessonProgress.fromDbRow(existing.first);
          if (local.isDirty || local.updatedAt.isAfter(item.updatedAt)) {
            continue;
          }
        }
        await txn.insert(
          'lesson_progress',
          item.toDbRow(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> markProgressSynced(String lessonId, DateTime syncedUpTo) async {
    await _db.update(
      'lesson_progress',
      {'is_dirty': 0},
      where: 'lesson_id = ? AND updated_at <= ?',
      whereArgs: [lessonId, syncedUpTo.toIso8601String()],
    );
  }

  Future<List<LessonProgress>> getDirtyProgress() async {
    final rows = await _db.query(
      'lesson_progress',
      where: 'is_dirty = 1',
    );
    return rows.map(LessonProgress.fromDbRow).toList(growable: false);
  }

  /// عدّادات صفحة «تقدّمي»: (المجموع، المكتمل، قيد التقدم) لكل مادة.
  Future<List<SubjectProgressSummary>> subjectSummaries() async {
    final rows = await _db.rawQuery('''
      SELECT s.id            AS subject_id,
             s.title         AS subject_title,
             COUNT(l.id)     AS total_lessons,
             SUM(CASE WHEN p.status = 'completed'   THEN 1 ELSE 0 END) AS completed,
             SUM(CASE WHEN p.status = 'in_progress' THEN 1 ELSE 0 END) AS in_progress
      FROM subjects s
      LEFT JOIN lessons l ON l.subject_id = s.id AND l.is_published = 1
      LEFT JOIN lesson_progress p ON p.lesson_id = l.id
      GROUP BY s.id, s.title
      ORDER BY s.position ASC, s.title ASC
    ''');

    return rows
        .map(
          (row) => SubjectProgressSummary(
            subjectId: row['subject_id']! as String,
            subjectTitle: row['subject_title']! as String,
            totalLessons: (row['total_lessons'] as int?) ?? 0,
            completedLessons: (row['completed'] as int?) ?? 0,
            inProgressLessons: (row['in_progress'] as int?) ?? 0,
          ),
        )
        .toList(growable: false);
  }

  // ------------------------------------------------------- محاولات الكويز

  Future<void> insertAttempt(QuizAttempt attempt) => _db.insert(
        'quiz_attempts',
        attempt.toDbRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  /// آخر إجابة لكل سؤال في الدرس، مفهرسة بـ `QuizAttempt.keyOf`.
  ///
  /// «الأحدث» تُحسب لكل (فقرة، سؤال) على حدة، فإعادة الكويز تُظهر الإجابات
  /// الجديدة دون حذف المحاولات السابقة (الأستاذ يحتاجها في الإحصائيات).
  Future<Map<String, QuizAttempt>> lastAttemptsForLesson(
    String lessonId,
  ) async {
    final rows = await _db.rawQuery(
      '''
      SELECT a.* FROM quiz_attempts a
      INNER JOIN (
        SELECT block_id, question_id, MAX(answered_at) AS max_at
        FROM quiz_attempts WHERE lesson_id = ?
        GROUP BY block_id, question_id
      ) latest
      ON a.block_id = latest.block_id
      AND a.question_id = latest.question_id
      AND a.answered_at = latest.max_at
      ''',
      [lessonId],
    );
    return {
      for (final row in rows)
        QuizAttempt.fromDbRow(row).key: QuizAttempt.fromDbRow(row),
    };
  }

  /// آخر إجابة لكل سؤال داخل فقرة واحدة، مفهرسة بمعرّف السؤال.
  Future<Map<String, QuizAttempt>> lastAttemptsForBlock(String blockId) async {
    final rows = await _db.rawQuery(
      '''
      SELECT a.* FROM quiz_attempts a
      INNER JOIN (
        SELECT question_id, MAX(answered_at) AS max_at
        FROM quiz_attempts WHERE block_id = ? GROUP BY question_id
      ) latest
      ON a.question_id = latest.question_id AND a.answered_at = latest.max_at
      WHERE a.block_id = ?
      ''',
      [blockId, blockId],
    );
    return {
      for (final row in rows)
        QuizAttempt.fromDbRow(row).questionId: QuizAttempt.fromDbRow(row),
    };
  }

  Future<void> markAttemptSynced(String attemptId) => _db.update(
        'quiz_attempts',
        {'is_dirty': 0},
        where: 'id = ?',
        whereArgs: [attemptId],
      );

  // -------------------------------------------------------- مستوى المادة

  Future<SubjectLevelChoice?> getLevel(String subjectId) async {
    final rows = await _db.query(
      'subject_levels',
      where: 'subject_id = ?',
      whereArgs: [subjectId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SubjectLevelChoice.fromDbRow(rows.first);
  }

  Future<Map<String, LessonLevel>> getAllLevels() async {
    final rows = await _db.query('subject_levels');
    return {
      for (final row in rows)
        row['subject_id']! as String:
            LessonLevel.fromWire(row['level'] as String?),
    };
  }

  Future<void> setLevel(SubjectLevelChoice choice) => _db.insert(
        'subject_levels',
        choice.toDbRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<void> mergeRemoteLevels(List<SubjectLevelChoice> remote) async {
    await _db.transaction((txn) async {
      for (final item in remote) {
        final existing = await txn.query(
          'subject_levels',
          where: 'subject_id = ?',
          whereArgs: [item.subjectId],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          final local = SubjectLevelChoice.fromDbRow(existing.first);
          if (local.isDirty || local.updatedAt.isAfter(item.updatedAt)) {
            continue;
          }
        }
        await txn.insert(
          'subject_levels',
          item.toDbRow(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> markLevelSynced(String subjectId) => _db.update(
        'subject_levels',
        {'is_dirty': 0},
        where: 'subject_id = ?',
        whereArgs: [subjectId],
      );
}
