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

    test('فقرة الفيديو تقرأ مرفقاتها وتعيد كتابتها', () {
      final block = LessonBlock.fromJson({
        'id': '2',
        'lesson_id': '10',
        'position': 0,
        'type': 'video',
        'data': {
          'url': 'https://cdn.example.com/a.mp4',
          'size_bytes': 1024,
          'attachments': [
            {
              'id': 'att-1',
              'file_name': 'ملخص.pdf',
              'url': 'https://cdn.example.com/a.pdf',
              'file_size': 2048,
            },
          ],
        },
      }) as VideoBlock;

      expect(block.attachments.length, 1);
      expect(block.attachments.single.fileName, 'ملخص.pdf');
      expect(block.attachments.single.sizeBytes, 2048);

      final restored = LessonBlock.fromDbRow(block.toDbRow()) as VideoBlock;
      expect(restored.attachments.single.id, 'att-1');
      expect(restored.attachments.single.url, 'https://cdn.example.com/a.pdf');
    });

    test('فقرة فيديو قديمة بلا مرفقات تبقى صالحة', () {
      final block = LessonBlock.fromJson({
        'id': '2',
        'lesson_id': '10',
        'position': 0,
        'type': 'video',
        'data': {'url': 'https://cdn.example.com/a.mp4'},
      }) as VideoBlock;

      expect(block.attachments, isEmpty);
    });

    test('المرفق بلا رابط يُتجاهل', () {
      final attachments = BlockAttachment.listFrom([
        {'id': 'a', 'file_name': 'x.pdf', 'url': ''},
        {'id': 'b', 'file_name': 'y.pdf', 'url': 'https://x/y.pdf'},
      ]);

      expect(attachments.map((a) => a.id), ['b']);
    });

    test('الشكل القديم (سؤال واحد في الجذر) يُقرأ كسؤال معرّفه معرّف الفقرة',
        () {
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

      expect(block.questions.length, 1);
      // المعرّف = معرّف الفقرة، فتبقى المحاولات القديمة مرتبطة بسؤالها.
      expect(block.questions.single.id, '3');
      expect(block.questions.single.options.length, 2);
      expect(block.questions.single.isCorrect('b'), isTrue);
      expect(block.questions.single.isCorrect('a'), isFalse);
    });

    test('الشكل الجديد يقرأ عدة أسئلة بالترتيب', () {
      final block = LessonBlock.fromJson({
        'id': '3',
        'lesson_id': '10',
        'position': 0,
        'type': 'quiz',
        'data': {
          'questions': [
            {
              'id': 'q1',
              'question': 'س١',
              'options': [
                {'id': 'a', 'text': 'أ'},
                {'id': 'b', 'text': 'ب'},
              ],
              'correct_option_id': 'a',
              'explanation': 'لأن…',
            },
            {
              'id': 'q2',
              'question': 'س٢',
              'options': [
                {'id': 'a', 'text': 'أ'},
                {'id': 'b', 'text': 'ب'},
              ],
              'correct_option_id': 'b',
            },
          ],
        },
      }) as QuizBlock;

      expect(block.questionsCount, 2);
      expect(block.questions.map((q) => q.id), ['q1', 'q2']);
      expect(block.questions[0].isCorrect('a'), isTrue);
      expect(block.questions[1].isCorrect('a'), isFalse);
      expect(block.questions[0].explanation, 'لأن…');
    });

    test('نصّ الإجابة الصحيحة يُقرأ لعرضه في بطاقة النتيجة', () {
      const question = QuizQuestion(
        id: 'q1',
        question: 'س',
        options: [
          QuizOption(id: 'a', text: 'أ'),
          QuizOption(id: 'b', text: 'ب'),
        ],
        correctOptionId: 'b',
      );

      expect(question.correctOptionText, 'ب');
    });

    test('سؤال بلا إجابة صحيحة لا يعتبر أي خيار صحيحًا', () {
      const question = QuizQuestion(
        id: 'q1',
        question: 'س',
        options: [QuizOption(id: 'a', text: 'أ')],
      );

      expect(question.isCorrect('a'), isFalse);
      expect(question.correctOptionText, isNull);
    });

    test('فقرة كويز فارغة لا تنهار', () {
      final block = LessonBlock.fromJson({
        'id': '5',
        'lesson_id': '10',
        'position': 0,
        'type': 'quiz',
        'data': <String, dynamic>{},
      }) as QuizBlock;

      expect(block.questions, isEmpty);
    });

    test('الأسئلة تعود كما هي بعد الحفظ والقراءة', () {
      const original = QuizBlock(
        id: '6',
        lessonId: '10',
        position: 0,
        questions: [
          QuizQuestion(
            id: 'q1',
            question: 'س١',
            options: [
              QuizOption(id: 'a', text: 'أ'),
              QuizOption(id: 'b', text: 'ب'),
            ],
            correctOptionId: 'b',
          ),
          QuizQuestion(
            id: 'q2',
            question: 'س٢',
            options: [
              QuizOption(id: 'a', text: 'أ'),
              QuizOption(id: 'b', text: 'ب'),
            ],
            correctOptionId: 'a',
          ),
        ],
      );

      final restored = LessonBlock.fromDbRow(original.toDbRow()) as QuizBlock;

      expect(restored.questionsCount, 2);
      expect(restored.questions[1].id, 'q2');
      expect(restored.questions[1].isCorrect('a'), isTrue);
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
