import 'package:education_app/core/storage/app_database.dart';
import 'package:education_app/core/storage/dao/content_dao.dart';
import 'package:education_app/core/storage/dao/outbox_dao.dart';
import 'package:education_app/core/storage/dao/progress_dao.dart';
import 'package:education_app/data/models/enums.dart';
import 'package:education_app/data/models/lesson.dart';
import 'package:education_app/data/models/lesson_block.dart';
import 'package:education_app/data/models/outbox_op.dart';
import 'package:education_app/data/models/progress.dart';
import 'package:education_app/data/models/subject.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// اختبارات قاعدة البيانات المحلية على SQLite حقيقي (في الذاكرة).
///
/// تغطّي أصعب أجزاء المنطق: دمج التقدّم القادم من الخادم دون دهس التغييرات
/// المحلية، ودمج عمليات طابور الإرسال عبر `dedupKey`.
void main() {
  late AppDatabase database;
  late ContentDao contentDao;
  late ProgressDao progressDao;
  late OutboxDao outboxDao;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = await AppDatabase.open(overridePath: inMemoryDatabasePath);
    contentDao = ContentDao(database);
    progressDao = ProgressDao(database);
    outboxDao = OutboxDao(database);
  });

  tearDown(() => database.close());

  Subject subject(String id) => Subject(id: id, title: 'مادة $id');

  Lesson lesson(String id, {String subjectId = 's1', LessonLevel? level}) =>
      Lesson(
        id: id,
        subjectId: subjectId,
        title: 'درس $id',
        level: level ?? LessonLevel.middle,
      );

  group('المحتوى', () {
    test('حفظ المواد واسترجاعها', () async {
      await contentDao.replaceSubjects([subject('s1'), subject('s2')]);

      final stored = await contentDao.getSubjects();
      expect(stored.length, 2);
      expect(stored.first.title, 'مادة s1');
    });

    test('استبدال المواد يحذف ما لم يعد موجودًا على الخادم', () async {
      await contentDao.replaceSubjects([subject('s1'), subject('s2')]);
      await contentDao.replaceSubjects([subject('s2')]);

      final stored = await contentDao.getSubjects();
      expect(stored.map((e) => e.id), ['s2']);
    });

    test('فلترة الدروس بالطور الدراسي', () async {
      await contentDao.replaceSubjects([subject('s1')]);
      await contentDao.replaceLessonsOfSubject('s1', [
        lesson('l1'),
        lesson('l2', level: LessonLevel.secondary),
      ]);

      final middle = await contentDao.getLessons(
        subjectId: 's1',
        level: LessonLevel.middle,
      );
      final secondary = await contentDao.getLessons(
        subjectId: 's1',
        level: LessonLevel.secondary,
      );

      expect(middle.map((e) => e.id), ['l1']);
      expect(secondary.map((e) => e.id), ['l2']);
    });

    test('حذف مادة يحذف دروسها وفقراتها', () async {
      await contentDao.replaceSubjects([subject('s1')]);
      await contentDao.replaceLessonsOfSubject('s1', [lesson('l1')]);
      await contentDao.replaceBlocks('l1', [
        const TextBlock(id: 'b1', lessonId: 'l1', position: 0, body: 'نص'),
      ]);

      await contentDao.deleteSubject('s1');

      expect(await contentDao.getLessons(subjectId: 's1'), isEmpty);
      expect(await contentDao.hasBlocks('l1'), isFalse);
    });

    test('الفقرات تُخزَّن وتُقرأ بأنواعها الصحيحة ومرتّبة', () async {
      await contentDao.replaceSubjects([subject('s1')]);
      await contentDao.replaceLessonsOfSubject('s1', [lesson('l1')]);
      await contentDao.replaceBlocks('l1', [
        const QuizBlock(
          id: 'b2',
          lessonId: 'l1',
          position: 1,
          question: 'س؟',
          options: [QuizOption(id: 'a', text: 'أ')],
          correctOptionId: 'a',
        ),
        const TextBlock(id: 'b1', lessonId: 'l1', position: 0, body: 'نص'),
      ]);

      final blocks = await contentDao.getBlocks('l1');

      expect(blocks.map((e) => e.id), ['b1', 'b2']);
      expect(blocks[0], isA<TextBlock>());
      expect(blocks[1], isA<QuizBlock>());
      expect((blocks[1] as QuizBlock).isCorrect('a'), isTrue);
    });

    test('إعادة ترتيب الدروس تُحفظ', () async {
      await contentDao.replaceSubjects([subject('s1')]);
      await contentDao.replaceLessonsOfSubject('s1', [
        lesson('l1'),
        lesson('l2'),
        lesson('l3'),
      ]);

      await contentDao.applyLessonOrder(['l3', 'l1', 'l2']);

      final ordered = await contentDao.getLessons(subjectId: 's1');
      expect(ordered.map((e) => e.id), ['l3', 'l1', 'l2']);
    });
  });

  group('دمج التقدّم', () {
    LessonProgress progress({
      required LessonStatus status,
      required DateTime updatedAt,
      bool isDirty = false,
      int lastBlockIndex = 0,
    }) =>
        LessonProgress(
          lessonId: 'l1',
          subjectId: 's1',
          status: status,
          lastBlockIndex: lastBlockIndex,
          blocksTotal: 5,
          updatedAt: updatedAt,
          isDirty: isDirty,
        );

    test('التغيير المحلي غير المرسل لا يُدهس بما يأتي من الخادم', () async {
      await progressDao.upsertProgress(
        progress(
          status: LessonStatus.completed,
          updatedAt: DateTime.utc(2026, 1, 1),
          isDirty: true,
          lastBlockIndex: 4,
        ),
      );

      // الخادم يرسل نسخة أحدث زمنيًا لكن المحلي لم يُرسل بعد.
      await progressDao.mergeRemoteProgress([
        progress(
          status: LessonStatus.inProgress,
          updatedAt: DateTime.utc(2026, 6, 1),
          lastBlockIndex: 1,
        ),
      ]);

      final stored = await progressDao.getProgress('l1');
      expect(stored!.status, LessonStatus.completed);
      expect(stored.lastBlockIndex, 4);
    });

    test('النسخة الأحدث من الخادم تفوز عندما لا يوجد تغيير محلي', () async {
      await progressDao.upsertProgress(
        progress(
          status: LessonStatus.inProgress,
          updatedAt: DateTime.utc(2026, 1, 1),
          lastBlockIndex: 1,
        ),
      );

      await progressDao.mergeRemoteProgress([
        progress(
          status: LessonStatus.completed,
          updatedAt: DateTime.utc(2026, 6, 1),
          lastBlockIndex: 4,
        ),
      ]);

      final stored = await progressDao.getProgress('l1');
      expect(stored!.status, LessonStatus.completed);
      expect(stored.lastBlockIndex, 4);
    });

    test('النسخة الأقدم من الخادم لا تُطبَّق', () async {
      await progressDao.upsertProgress(
        progress(
          status: LessonStatus.completed,
          updatedAt: DateTime.utc(2026, 6, 1),
          lastBlockIndex: 4,
        ),
      );

      await progressDao.mergeRemoteProgress([
        progress(
          status: LessonStatus.notStarted,
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      ]);

      expect(
        (await progressDao.getProgress('l1'))!.status,
        LessonStatus.completed,
      );
    });

    test('ملخّص المواد يحسب الدروس المكتملة', () async {
      await contentDao.replaceSubjects([subject('s1')]);
      await contentDao.replaceLessonsOfSubject('s1', [
        lesson('l1'),
        lesson('l2'),
        lesson('l3'),
      ]);
      await progressDao.upsertProgress(
        LessonProgress(
          lessonId: 'l1',
          subjectId: 's1',
          status: LessonStatus.completed,
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      );
      await progressDao.upsertProgress(
        LessonProgress(
          lessonId: 'l2',
          subjectId: 's1',
          status: LessonStatus.inProgress,
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      );

      final summaries = await progressDao.subjectSummaries();

      expect(summaries.length, 1);
      expect(summaries.first.totalLessons, 3);
      expect(summaries.first.completedLessons, 1);
      expect(summaries.first.inProgressLessons, 1);
    });
  });

  group('طابور الإرسال', () {
    OutboxOp op(String id, {String? dedupKey, OutboxKind? kind}) => OutboxOp(
          id: id,
          kind: kind ?? OutboxKind.lessonProgress,
          payload: {'n': id},
          dedupKey: dedupKey,
          createdAt: DateTime.now().toUtc(),
          nextAttemptAt: DateTime.now().toUtc(),
        );

    test('العملية الأحدث تستبدل السابقة بنفس مفتاح الدمج', () async {
      await outboxDao.enqueue(op('1', dedupKey: 'progress:l1'));
      await outboxDao.enqueue(op('2', dedupKey: 'progress:l1'));

      final ready = await outboxDao.readyOps();
      expect(ready.length, 1);
      expect(ready.first.id, '2');
    });

    test('عمليات بمفاتيح مختلفة تبقى كلها', () async {
      await outboxDao.enqueue(op('1', dedupKey: 'progress:l1'));
      await outboxDao.enqueue(op('2', dedupKey: 'progress:l2'));

      expect(await outboxDao.pendingCount(), 2);
    });

    test('محاولات الكويز لا تُدمج أبدًا', () async {
      await outboxDao.enqueue(op('1', kind: OutboxKind.quizAttempt));
      await outboxDao.enqueue(op('2', kind: OutboxKind.quizAttempt));

      expect(await outboxDao.pendingCount(), 2);
    });

    test('العملية المؤجَّلة لا تظهر ضمن الجاهزة', () async {
      await outboxDao.enqueue(
        OutboxOp(
          id: 'later',
          kind: OutboxKind.lessonProgress,
          payload: const {},
          createdAt: DateTime.now().toUtc(),
          nextAttemptAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        ),
      );

      expect(await outboxDao.readyOps(), isEmpty);
      expect(await outboxDao.pendingCount(), 1);
    });

    test('إعادة محاولة الفاشلة تعيدها إلى الطابور', () async {
      var failed = op('1');
      for (var i = 0; i < 10; i++) {
        failed = failed.markFailed('خطأ');
      }
      await outboxDao.update(failed);
      expect(await outboxDao.failedCount(), 1);

      await outboxDao.retryAllFailed();

      expect(await outboxDao.failedCount(), 0);
      expect((await outboxDao.readyOps()).length, 1);
    });
  });

  test('تسجيل الخروج يمسح كل بيانات المستخدم', () async {
    await contentDao.replaceSubjects([subject('s1')]);
    await contentDao.replaceLessonsOfSubject('s1', [lesson('l1')]);
    await outboxDao.enqueue(
      OutboxOp(
        id: '1',
        kind: OutboxKind.quizAttempt,
        payload: const {},
        createdAt: DateTime.now().toUtc(),
        nextAttemptAt: DateTime.now().toUtc(),
      ),
    );

    await database.wipeUserData();

    expect(await contentDao.getSubjects(), isEmpty);
    expect(await contentDao.getLessons(subjectId: 's1'), isEmpty);
    expect(await outboxDao.pendingCount(), 0);
  });
}
