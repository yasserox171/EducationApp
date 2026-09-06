import 'package:education_app/data/models/enums.dart';
import 'package:education_app/data/models/lesson_block.dart';
import 'package:education_app/data/models/progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LessonBlock', () {
    test('يقرأ فقرة نصية من JSON', () {
      final block = LessonBlock.fromJson({
        'id': '1',
        'lesson_id': '10',
        'position': 0,
        'type': 'text',
        'data': {'heading': 'مقدمة', 'body': 'نص الفقرة'},
      });

      expect(block, isA<TextBlock>());
      expect(block.type, BlockType.text);
      expect((block as TextBlock).heading, 'مقدمة');
      expect(block.body, 'نص الفقرة');
    });

    test('يقرأ فقرة فيديو ويقبل url أو remote_url', () {
      final block = LessonBlock.fromJson({
        'id': '2',
        'lesson_id': '10',
        'position': 1,
        'type': 'video',
        'data': {
          'url': 'https://cdn.example.com/a.mp4',
          'duration_seconds': 90,
          'size_bytes': 1024,
        },
      }) as VideoBlock;

      expect(block.remoteUrl, 'https://cdn.example.com/a.mp4');
      expect(block.durationSeconds, 90);
      expect(block.sizeBytes, 1024);
    });

    test('الكويز يصحّح الإجابة محليًا', () {
      final block = LessonBlock.fromJson({
        'id': '3',
        'lesson_id': '10',
        'position': 2,
        'type': 'quiz',
        'data': {
          'question': 'ما الناتج؟',
          'options': [
            {'id': 'a', 'text': '٢'},
            {'id': 'b', 'text': '٣'},
          ],
          'correct_option_id': 'b',
        },
      }) as QuizBlock;

      expect(block.options.length, 2);
      expect(block.isCorrect('b'), isTrue);
      expect(block.isCorrect('a'), isFalse);
    });

    test('كويز بلا إجابة صحيحة لا يعتبر أي خيار صحيحًا', () {
      const block = QuizBlock(
        id: '4',
        lessonId: '10',
        position: 0,
        question: 'س',
        options: [QuizOption(id: 'a', text: 'أ')],
      );

      expect(block.isCorrect('a'), isFalse);
    });

    test('الذهاب إلى صف قاعدة البيانات والعودة منه يحفظ البيانات', () {
      const original = TextBlock(
        id: '5',
        lessonId: '10',
        position: 3,
        heading: 'عنوان',
        body: 'محتوى',
      );

      final restored = LessonBlock.fromDbRow(original.toDbRow()) as TextBlock;

      expect(restored.id, original.id);
      expect(restored.lessonId, original.lessonId);
      expect(restored.position, original.position);
      expect(restored.heading, original.heading);
      expect(restored.body, original.body);
    });

    test('نوع غير معروف يُعامل كنص بدل الانهيار', () {
      final block = LessonBlock.fromJson({
        'id': '6',
        'lesson_id': '10',
        'position': 0,
        'type': 'something_new',
        'data': <String, dynamic>{},
      });

      expect(block, isA<TextBlock>());
    });
  });

  group('LessonProgress', () {
    test('النسبة تُحسب من الفقرة الحالية', () {
      final progress = LessonProgress(
        lessonId: '10',
        subjectId: '1',
        status: LessonStatus.inProgress,
        lastBlockIndex: 2,
        blocksTotal: 4,
        updatedAt: DateTime.utc(2026, 9, 6),
      );

      expect(progress.ratio, 0.75);
    });

    test('النسبة صفر عندما لا توجد فقرات', () {
      final progress = LessonProgress(
        lessonId: '10',
        subjectId: '1',
        status: LessonStatus.notStarted,
        updatedAt: DateTime.utc(2026, 9, 6),
      );

      expect(progress.ratio, 0);
    });

    test('النسبة لا تتجاوز ١ حتى لو تجاوز المؤشّر العدد', () {
      final progress = LessonProgress(
        lessonId: '10',
        subjectId: '1',
        status: LessonStatus.completed,
        lastBlockIndex: 9,
        blocksTotal: 3,
        updatedAt: DateTime.utc(2026, 9, 6),
      );

      expect(progress.ratio, 1.0);
    });
  });

  group('التعدادات', () {
    test('قيمة غير معروفة ترجع إلى الافتراضي', () {
      expect(UserRole.fromWire('unknown'), UserRole.student);
      expect(LessonLevel.fromWire(null), LessonLevel.middle);
      expect(LessonStatus.fromWire('x'), LessonStatus.notStarted);
      expect(DownloadStatus.fromWire(null), DownloadStatus.none);
    });

    test('قيم السلك مطابقة للعقد مع الخادم', () {
      expect(LessonLevel.secondary.wire, 'secondary');
      expect(LessonLevel.middle.label, 'متوسط');
      expect(LessonStatus.inProgress.wire, 'in_progress');
    });
  });
}
