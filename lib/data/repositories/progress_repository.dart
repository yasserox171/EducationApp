import 'package:uuid/uuid.dart';

import '../../core/storage/dao/outbox_dao.dart';
import '../../core/storage/dao/progress_dao.dart';
import '../models/enums.dart';
import '../models/lesson_block.dart';
import '../models/outbox_op.dart';
import '../models/progress.dart';

/// تقدّم التلميذ: كل كتابة محلية أولًا ثم تُوضع في طابور الإرسال.
///
/// لا شيء هنا ينتظر الشبكة — الواجهة تستجيب فورًا حتى بدون إنترنت.
class ProgressRepository {
  ProgressRepository({
    required ProgressDao dao,
    required OutboxDao outbox,
    Uuid? uuid,
  })  : _dao = dao,
        _outbox = outbox,
        _uuid = uuid ?? const Uuid();

  final ProgressDao _dao;
  final OutboxDao _outbox;
  final Uuid _uuid;

  // ------------------------------------------------------------ التقدّم

  Future<LessonProgress?> getProgress(String lessonId) =>
      _dao.getProgress(lessonId);

  Future<Map<String, LessonProgress>> getProgressForSubject(String subjectId) =>
      _dao.getProgressForSubject(subjectId);

  Future<List<SubjectProgressSummary>> getSummaries() => _dao.subjectSummaries();

  /// تُستدعى عند كل تنقّل بين الفقرات: تحفظ آخر موضع وصل إليه التلميذ.
  Future<LessonProgress> savePosition({
    required String lessonId,
    required String subjectId,
    required int blockIndex,
    required int blocksTotal,
  }) async {
    final existing = await _dao.getProgress(lessonId);
    final isCompleted = blocksTotal > 0 && blockIndex >= blocksTotal - 1;

    // لا نتراجع بمؤشّر الموضع إلى الخلف عند إعادة تصفّح الدرس.
    final furthestIndex = existing == null
        ? blockIndex
        : (blockIndex > existing.lastBlockIndex
            ? blockIndex
            : existing.lastBlockIndex);

    final wasCompleted = existing?.status == LessonStatus.completed;

    final progress = LessonProgress(
      lessonId: lessonId,
      subjectId: subjectId,
      status: isCompleted || wasCompleted
          ? LessonStatus.completed
          : LessonStatus.inProgress,
      lastBlockIndex: furthestIndex,
      blocksTotal: blocksTotal,
      completedAt: wasCompleted
          ? existing?.completedAt
          : (isCompleted ? DateTime.now().toUtc() : null),
      updatedAt: DateTime.now().toUtc(),
      isDirty: true,
    );

    await _dao.upsertProgress(progress);
    await _enqueueProgress(progress);
    return progress;
  }

  Future<void> markCompleted({
    required String lessonId,
    required String subjectId,
    required int blocksTotal,
  }) async {
    final now = DateTime.now().toUtc();
    final progress = LessonProgress(
      lessonId: lessonId,
      subjectId: subjectId,
      status: LessonStatus.completed,
      lastBlockIndex: blocksTotal == 0 ? 0 : blocksTotal - 1,
      blocksTotal: blocksTotal,
      completedAt: now,
      updatedAt: now,
      isDirty: true,
    );
    await _dao.upsertProgress(progress);
    await _enqueueProgress(progress);
  }

  Future<void> _enqueueProgress(LessonProgress progress) => _outbox.enqueue(
        OutboxOp(
          id: _uuid.v4(),
          kind: OutboxKind.lessonProgress,
          payload: progress.toJson(),
          // تحديث واحد لكل درس يكفي: الأحدث يستبدل ما قبله في الطابور.
          dedupKey: 'progress:${progress.lessonId}',
          createdAt: DateTime.now().toUtc(),
          nextAttemptAt: DateTime.now().toUtc(),
        ),
      );

  // ------------------------------------------------------------- الكويز

  /// تسجيل إجابة كويز. التصحيح فوري ومحلي (لا ينتظر الخادم).
  Future<QuizAttempt> answerQuiz({
    required QuizBlock block,
    required String selectedOptionId,
  }) async {
    final attempt = QuizAttempt(
      id: _uuid.v4(),
      blockId: block.id,
      lessonId: block.lessonId,
      selectedOptionId: selectedOptionId,
      isCorrect: block.isCorrect(selectedOptionId),
      answeredAt: DateTime.now().toUtc(),
    );

    await _dao.insertAttempt(attempt);
    await _outbox.enqueue(
      OutboxOp(
        id: _uuid.v4(),
        kind: OutboxKind.quizAttempt,
        payload: attempt.toJson(),
        // كل محاولة تُرسل على حدة (لا دمج): الأستاذ يحتاج كل النتائج.
        createdAt: DateTime.now().toUtc(),
        nextAttemptAt: DateTime.now().toUtc(),
      ),
    );
    return attempt;
  }

  Future<Map<String, QuizAttempt>> attemptsForLesson(String lessonId) =>
      _dao.lastAttemptsForLesson(lessonId);

  // -------------------------------------------------------- مستوى المادة

  Future<LessonLevel?> getLevel(String subjectId) async {
    final choice = await _dao.getLevel(subjectId);
    return choice?.level;
  }

  Future<Map<String, LessonLevel>> getAllLevels() => _dao.getAllLevels();

  Future<void> setLevel({
    required String subjectId,
    required LessonLevel level,
  }) async {
    final choice = SubjectLevelChoice(
      subjectId: subjectId,
      level: level,
      updatedAt: DateTime.now().toUtc(),
      isDirty: true,
    );
    await _dao.setLevel(choice);
    await _outbox.enqueue(
      OutboxOp(
        id: _uuid.v4(),
        kind: OutboxKind.subjectLevel,
        payload: choice.toJson(),
        dedupKey: 'level:$subjectId',
        createdAt: DateTime.now().toUtc(),
        nextAttemptAt: DateTime.now().toUtc(),
      ),
    );
  }
}
