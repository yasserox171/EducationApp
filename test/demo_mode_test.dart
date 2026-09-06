import 'package:education_app/core/error/app_exception.dart';
import 'package:education_app/data/demo/demo_api_client.dart';
import 'package:education_app/data/demo/demo_data.dart';
import 'package:education_app/data/models/enums.dart';
import 'package:education_app/data/models/lesson.dart';
import 'package:education_app/data/models/lesson_block.dart';
import 'package:education_app/data/models/subject.dart';
import 'package:education_app/data/models/teacher_stats.dart';
import 'package:education_app/data/models/user.dart';
import 'package:education_app/data/remote/auth_api.dart';
import 'package:education_app/data/remote/content_api.dart';
import 'package:education_app/data/remote/progress_api.dart';
import 'package:education_app/data/remote/stats_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// اختبارات وضع التجربة: تمرّ عبر نفس خدمات الـ API التي يستعملها التطبيق،
/// فتتحقّق أن الخادم الوهمي يفهم كل المسارات ويعيد بيانات صالحة للنماذج.
void main() {
  late DemoApiClient client;
  late AuthApi authApi;
  late ContentApi contentApi;
  late ProgressApi progressApi;
  late StatsApi statsApi;

  setUp(() {
    client = DemoApiClient();
    authApi = AuthApi(client);
    contentApi = ContentApi(client);
    progressApi = ProgressApi(client);
    statsApi = StatsApi(client);
  });

  group('الدخول', () {
    test('حساب الأستاذ التجريبي يعمل', () async {
      final session = await authApi.login(
        email: DemoUsers.teacherEmail,
        password: DemoUsers.password,
      );

      expect(session.token, isNotEmpty);
      expect(session.user.role, UserRole.teacher);
      expect(session.user.fullName, isNotEmpty);
    });

    test('حساب التلميذ التجريبي يعمل', () async {
      final session = await authApi.login(
        email: DemoUsers.studentEmail,
        password: DemoUsers.password,
      );

      expect(session.user.role, UserRole.student);
    });

    test('البريد يُقبل بأحرف كبيرة ومسافات', () async {
      final session = await authApi.login(
        email: '  ${DemoUsers.studentEmail.toUpperCase()} ',
        password: DemoUsers.password,
      );

      expect(session.user.role, UserRole.student);
    });

    test('كلمة سر خاطئة تُرفض', () {
      expect(
        () => authApi.login(
          email: DemoUsers.studentEmail,
          password: 'wrong',
        ),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('بريد غير معروف يُرفض', () {
      expect(
        () => authApi.login(
          email: 'ghost@demo.dz',
          password: DemoUsers.password,
        ),
        throwsA(isA<UnauthorizedException>()),
      );
    });
  });

  group('المحتوى التجريبي', () {
    test('المواد تُقرأ ولها دروس', () async {
      final subjects = await contentApi.fetchSubjects();

      expect(subjects.length, 3);
      expect(subjects.every((Subject s) => s.title.isNotEmpty), isTrue);
      expect(subjects.first.lessonsCount, greaterThan(0));
    });

    test('كل مادة فيها دروس في الطورين أو أحدهما، والفلترة تعمل', () async {
      final subjects = await contentApi.fetchSubjects();
      var middleTotal = 0;
      var secondaryTotal = 0;

      for (final subject in subjects) {
        final middle = await contentApi.fetchLessons(
          subject.id,
          level: LessonLevel.middle,
        );
        final secondary = await contentApi.fetchLessons(
          subject.id,
          level: LessonLevel.secondary,
        );
        expect(
          middle.every((Lesson l) => l.level == LessonLevel.middle),
          isTrue,
        );
        expect(
          secondary.every((Lesson l) => l.level == LessonLevel.secondary),
          isTrue,
        );
        middleTotal += middle.length;
        secondaryTotal += secondary.length;
      }

      expect(middleTotal, greaterThan(0));
      expect(secondaryTotal, greaterThan(0));
    });

    test('كل درس له فقرات صالحة ومرتّبة', () async {
      final subjects = await contentApi.fetchSubjects();
      var totalBlocks = 0;
      var quizCount = 0;
      var videoCount = 0;

      for (final subject in subjects) {
        for (final lesson in await contentApi.fetchLessons(subject.id)) {
          final blocks = await contentApi.fetchBlocks(lesson.id);
          expect(blocks, isNotEmpty, reason: 'الدرس ${lesson.id} بلا فقرات');

          for (var i = 0; i < blocks.length; i++) {
            expect(blocks[i].position, i);
            expect(blocks[i].lessonId, lesson.id);
          }
          totalBlocks += blocks.length;
          quizCount += blocks.whereType<QuizBlock>().length;
          videoCount += blocks.whereType<VideoBlock>().length;
        }
      }

      expect(totalBlocks, greaterThan(20));
      expect(quizCount, greaterThan(5));
      expect(videoCount, greaterThan(2));
    });

    test('كل كويز له إجابة صحيحة ضمن خياراته (شرط التصحيح الأوفلاين)',
        () async {
      final subjects = await contentApi.fetchSubjects();

      for (final subject in subjects) {
        for (final lesson in await contentApi.fetchLessons(subject.id)) {
          final quizzes = (await contentApi.fetchBlocks(lesson.id))
              .whereType<QuizBlock>();
          for (final quiz in quizzes) {
            expect(quiz.options.length, greaterThanOrEqualTo(2));
            expect(
              quiz.options.any((o) => o.id == quiz.correctOptionId),
              isTrue,
              reason: 'الكويز ${quiz.id} بلا إجابة صحيحة صالحة',
            );
            expect(quiz.isCorrect(quiz.correctOptionId!), isTrue);
          }
        }
      }
    });

    test('روابط الفيديو صالحة ولها حجم معلن', () async {
      final blocks = await contentApi.fetchBlocks('l-math-1');
      final video = blocks.whereType<VideoBlock>().first;

      expect(video.remoteUrl, startsWith('https://'));
      expect(video.sizeBytes, greaterThan(0));
    });
  });

  group('عمليات الأستاذ', () {
    test('إنشاء مادة ثم تعديلها ثم حذفها', () async {
      final created = await contentApi.createSubject(title: 'مادة جديدة');
      expect((await contentApi.fetchSubjects()).length, 4);

      final updated = await contentApi.updateSubject(
        created.id,
        title: 'مادة معدّلة',
      );
      expect(updated.title, 'مادة معدّلة');

      await contentApi.deleteSubject(created.id);
      expect((await contentApi.fetchSubjects()).length, 3);
    });

    test('حذف مادة يحذف دروسها', () async {
      await contentApi.deleteSubject('s-math');

      final lessons = await contentApi.fetchLessons('s-math');
      expect(lessons, isEmpty);
    });

    test('إضافة فقرات بالأنواع الثلاثة إلى درس', () async {
      final lesson = await contentApi.createLesson(
        subjectId: 's-math',
        title: 'درس تجريبي',
        level: LessonLevel.middle,
      );

      await contentApi.createBlock(
        lessonId: lesson.id,
        type: BlockType.text,
        data: {'heading': 'عنوان', 'body': 'نص'},
      );
      await contentApi.createBlock(
        lessonId: lesson.id,
        type: BlockType.quiz,
        data: {
          'question': 'س؟',
          'options': [
            {'id': 'a', 'text': 'أ'},
            {'id': 'b', 'text': 'ب'},
          ],
          'correct_option_id': 'b',
        },
      );

      final blocks = await contentApi.fetchBlocks(lesson.id);
      expect(blocks.length, 2);
      expect(blocks[0], isA<TextBlock>());
      expect(blocks[1], isA<QuizBlock>());
      expect((blocks[1] as QuizBlock).isCorrect('b'), isTrue);
    });

    test('إعادة ترتيب الدروس تنعكس على القراءة', () async {
      final before = await contentApi.fetchLessons('s-math');
      final reversed = before.reversed.map((lesson) => lesson.id).toList();

      await contentApi.reorderLessons(
        subjectId: 's-math',
        orderedIds: reversed,
      );

      final after = await contentApi.fetchLessons('s-math');
      expect(after.map((lesson) => lesson.id).toList(), reversed);
    });

    test('حذف فقرة يُنقص عدّاد فقرات الدرس', () async {
      final blocks = await contentApi.fetchBlocks('l-math-1');
      await contentApi.deleteBlock(blocks.first.id);

      final after = await contentApi.fetchBlocks('l-math-1');
      expect(after.length, blocks.length - 1);
    });
  });

  group('تقدّم التلميذ والإحصائيات', () {
    test('دفع التقدّم ثم قراءته يعيد نفس القيم', () async {
      await progressApi.pushProgress({
        'lesson_id': 'l-math-1',
        'subject_id': 's-math',
        'status': 'completed',
        'last_block_index': 4,
        'blocks_total': 5,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      final progress = await progressApi.fetchMyProgress();
      expect(progress.length, 1);
      expect(progress.first.lessonId, 'l-math-1');
      expect(progress.first.status, LessonStatus.completed);
    });

    test('اختيار الطور يُحفظ ويُقرأ', () async {
      await progressApi.pushLevel(
        subjectId: 's-math',
        level: LessonLevel.secondary,
      );

      final levels = await progressApi.fetchMyLevels();
      expect(levels.single.subjectId, 's-math');
      expect(levels.single.level, LessonLevel.secondary);
    });

    test('إرسال نفس محاولة الكويز مرتين لا يُسجّلها مرتين', () async {
      final payload = {
        'id': 'attempt-1',
        'block_id': 'b-m1-4',
        'lesson_id': 'l-math-1',
        'selected_option_id': 'b',
        'is_correct': true,
        'answered_at': DateTime.now().toUtc().toIso8601String(),
      };

      await progressApi.pushQuizAttempt(payload);
      await progressApi.pushQuizAttempt(payload);

      final stats = await statsApi.fetchTeacherStats();
      final lesson = stats.lessons.firstWhere(
        (LessonStats item) => item.lessonId == 'l-math-1',
      );
      expect(lesson.averageQuizScore, 1.0);
    });

    test('الإحصائيات تعكس كل الدروس وتحسب نسب صالحة', () async {
      final stats = await statsApi.fetchTeacherStats();

      expect(stats.studentsCount, greaterThan(0));
      expect(stats.lessons.length, 9);
      for (final lesson in stats.lessons) {
        expect(lesson.completionRate, inInclusiveRange(0.0, 1.0));
        expect(lesson.lessonTitle, isNotEmpty);
        expect(lesson.subjectTitle, isNotEmpty);
      }
    });

    test('إكمال درس يرفع عدد من أكملوه في الإحصائيات', () async {
      final before = await statsApi.fetchTeacherStats();
      final beforeLesson = before.lessons
          .firstWhere((LessonStats item) => item.lessonId == 'l-phy-1');

      await progressApi.pushProgress({
        'lesson_id': 'l-phy-1',
        'subject_id': 's-physics',
        'status': 'completed',
        'last_block_index': 3,
        'blocks_total': 4,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      final after = await statsApi.fetchTeacherStats();
      final afterLesson = after.lessons
          .firstWhere((LessonStats item) => item.lessonId == 'l-phy-1');

      expect(afterLesson.studentsCompleted, beforeLesson.studentsCompleted + 1);
    });
  });

  test('المستخدم الحالي يُقرأ بعد الدخول', () async {
    await authApi.login(
      email: DemoUsers.teacherEmail,
      password: DemoUsers.password,
    );

    final me = await authApi.me();
    expect(me, isA<AppUser>());
    expect(me.isTeacher, isTrue);
  });
}
