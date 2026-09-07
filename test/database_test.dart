import 'package:education_app/core/storage/app_database.dart';
import 'package:education_app/core/storage/dao/content_dao.dart';
import 'package:education_app/core/storage/dao/outbox_dao.dart';
import 'package:education_app/core/storage/dao/progress_dao.dart';
import 'package:education_app/data/models/download_state.dart';
import 'package:education_app/data/models/enums.dart';
import 'package:education_app/data/models/lesson.dart';
import 'package:education_app/data/models/lesson_block.dart';
import 'package:education_app/data/models/outbox_op.dart';
import 'package:education_app/data/models/progress.dart';
import 'package:education_app/data/models/subject.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
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
          questions: [
            QuizQuestion(
              id: 'q1',
              question: 'س؟',
              options: [QuizOption(id: 'a', text: 'أ')],
              correctOptionId: 'a',
            ),
          ],
        ),
        const TextBlock(id: 'b1', lessonId: 'l1', position: 0, body: 'نص'),
      ]);

      final blocks = await contentDao.getBlocks('l1');

      expect(blocks.map((e) => e.id), ['b1', 'b2']);
      expect(blocks[0], isA<TextBlock>());
      expect(blocks[1], isA<QuizBlock>());
      expect(
        (blocks[1] as QuizBlock).questions.single.isCorrect('a'),
        isTrue,
      );
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

  group('محاولات الكويز', () {
    QuizAttempt attempt({
      required String questionId,
      required String optionId,
      required bool isCorrect,
      required DateTime at,
      String blockId = 'b1',
    }) =>
        QuizAttempt(
          id: '$blockId-$questionId-${at.microsecondsSinceEpoch}',
          blockId: blockId,
          questionId: questionId,
          lessonId: 'l1',
          selectedOptionId: optionId,
          isCorrect: isCorrect,
          answeredAt: at,
        );

    test('كل سؤال يحتفظ بإجابته المستقلة داخل الفقرة نفسها', () async {
      await progressDao.insertAttempt(
        attempt(
          questionId: 'q1',
          optionId: 'a',
          isCorrect: true,
          at: DateTime.utc(2026, 1, 1),
        ),
      );
      await progressDao.insertAttempt(
        attempt(
          questionId: 'q2',
          optionId: 'b',
          isCorrect: false,
          at: DateTime.utc(2026, 1, 1, 1),
        ),
      );

      final byQuestion = await progressDao.lastAttemptsForBlock('b1');

      expect(byQuestion.length, 2);
      expect(byQuestion['q1']!.isCorrect, isTrue);
      expect(byQuestion['q2']!.isCorrect, isFalse);
    });

    test('إعادة الكويز: الأحدث لكل سؤال يفوز والقديم يبقى محفوظًا', () async {
      await progressDao.insertAttempt(
        attempt(
          questionId: 'q1',
          optionId: 'a',
          isCorrect: false,
          at: DateTime.utc(2026, 1, 1),
        ),
      );
      await progressDao.insertAttempt(
        attempt(
          questionId: 'q1',
          optionId: 'b',
          isCorrect: true,
          at: DateTime.utc(2026, 2, 1),
        ),
      );

      final byQuestion = await progressDao.lastAttemptsForBlock('b1');
      expect(byQuestion['q1']!.selectedOptionId, 'b');
      expect(byQuestion['q1']!.isCorrect, isTrue);

      // المحاولة الأقدم لم تُحذف: الأستاذ يحتاجها في الإحصائيات.
      final all = await database.db.query('quiz_attempts');
      expect(all.length, 2);
    });

    test('أسئلة فقرتين مختلفتين لا تتصادم رغم تشابه المعرّفات', () async {
      await progressDao.insertAttempt(
        attempt(
          questionId: 'q1',
          optionId: 'a',
          isCorrect: true,
          at: DateTime.utc(2026, 1, 1),
        ),
      );
      await progressDao.insertAttempt(
        attempt(
          blockId: 'b2',
          questionId: 'q1',
          optionId: 'b',
          isCorrect: false,
          at: DateTime.utc(2026, 1, 2),
        ),
      );

      final byKey = await progressDao.lastAttemptsForLesson('l1');

      expect(byKey.length, 2);
      expect(byKey[QuizAttempt.keyOf('b1', 'q1')]!.isCorrect, isTrue);
      expect(byKey[QuizAttempt.keyOf('b2', 'q1')]!.isCorrect, isFalse);
    });
  });

  group('ترقية قاعدة البيانات', () {
    test('محاولات الإصدار الأول تُنسب إلى سؤال الفقرة بعد الترقية', () async {
      // ملف مستقل لا قاعدة في الذاكرة: قواعد `:memory:` مشتركة هنا،
      // فلو استعملناها لالتقطنا قاعدة الاختبار الحالية بمخطّطها الجديد.
      final dir = Directory.systemTemp.createTempSync('edu_migration_');
      addTearDown(() => dir.deleteSync(recursive: true));

      final legacy = await databaseFactory.openDatabase(
        p.join(dir.path, 'legacy.db'),
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE quiz_attempts (
                id TEXT PRIMARY KEY,
                block_id TEXT NOT NULL,
                lesson_id TEXT NOT NULL,
                selected_option_id TEXT NOT NULL,
                is_correct INTEGER NOT NULL DEFAULT 0,
                answered_at TEXT NOT NULL,
                is_dirty INTEGER NOT NULL DEFAULT 1
              )
            ''');
            await db.insert('quiz_attempts', {
              'id': 'old-1',
              'block_id': 'b-legacy',
              'lesson_id': 'l1',
              'selected_option_id': 'a',
              'is_correct': 1,
              'answered_at': DateTime.utc(2026, 1, 1).toIso8601String(),
              'is_dirty': 0,
            });
          },
        ),
      );
      addTearDown(legacy.close);

      await AppDatabase.debugMigrateToV2(legacy);

      final rows = await legacy.query('quiz_attempts');
      expect(rows.single['question_id'], 'b-legacy');

      final restored = QuizAttempt.fromDbRow(rows.single);
      expect(restored.questionId, 'b-legacy');
      expect(restored.isCorrect, isTrue);
    });

    test('ملفات الوسائط القديمة تصبح ملفات فيديو بمعرّف فقرتها', () async {
      final dir = Directory.systemTemp.createTempSync('edu_media_migration_');
      addTearDown(() => dir.deleteSync(recursive: true));

      final legacy = await databaseFactory.openDatabase(
        p.join(dir.path, 'legacy.db'),
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE media_files (
                block_id TEXT PRIMARY KEY,
                lesson_id TEXT NOT NULL,
                remote_url TEXT NOT NULL,
                local_path TEXT,
                bytes_total INTEGER NOT NULL DEFAULT 0,
                bytes_downloaded INTEGER NOT NULL DEFAULT 0,
                status TEXT NOT NULL DEFAULT 'none',
                error TEXT,
                updated_at TEXT NOT NULL
              )
            ''');
            await db.insert('media_files', {
              'block_id': 'b-video',
              'lesson_id': 'l1',
              'remote_url': 'https://x/a.mp4',
              'local_path': '/tmp/a.mp4',
              'bytes_total': 100,
              'bytes_downloaded': 100,
              'status': 'completed',
              'updated_at': DateTime.utc(2026, 1, 1).toIso8601String(),
            });
          },
        ),
      );
      addTearDown(legacy.close);

      await AppDatabase.debugMigrateToV3(legacy);

      final rows = await legacy.query('media_files');
      final file = MediaFile.fromDbRow(rows.single);

      // الدرس المحمَّل يبقى محمَّلًا: لا إعادة تنزيل بعد الترقية.
      expect(file.fileId, 'b-video');
      expect(file.blockId, 'b-video');
      expect(file.kind, MediaKind.video);
      expect(file.isReady, isTrue);
      expect(file.localPath, '/tmp/a.mp4');
    });

    test('الترقية لا تكرّر العمود إن طُبّقت مرتين', () async {
      await AppDatabase.debugMigrateToV2(database.db);
      await AppDatabase.debugMigrateToV2(database.db);

      final columns =
          await database.db.rawQuery('PRAGMA table_info(quiz_attempts)');
      final questionColumns =
          columns.where((c) => c['name'] == 'question_id').length;
      expect(questionColumns, 1);
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
