/// التعدادات المشتركة، مع قيمة السلك (`wire`) المتفق عليها مع الـ API
/// وتسمية عربية للعرض.
library;

enum UserRole {
  teacher('teacher', 'أستاذ'),
  student('student', 'تلميذ');

  const UserRole(this.wire, this.label);

  final String wire;
  final String label;

  static UserRole fromWire(String? value) => switch (value) {
        'teacher' => UserRole.teacher,
        _ => UserRole.student,
      };
}

/// الطور الدراسي للدرس: متوسط / ثانوي.
enum LessonLevel {
  middle('middle', 'متوسط'),
  secondary('secondary', 'ثانوي');

  const LessonLevel(this.wire, this.label);

  final String wire;
  final String label;

  static LessonLevel fromWire(String? value) => switch (value) {
        'secondary' => LessonLevel.secondary,
        _ => LessonLevel.middle,
      };
}

/// نوع الفقرة داخل الدرس.
enum BlockType {
  text('text', 'نص'),
  video('video', 'فيديو'),
  quiz('quiz', 'كويز');

  const BlockType(this.wire, this.label);

  final String wire;
  final String label;

  static BlockType fromWire(String? value) => switch (value) {
        'video' => BlockType.video,
        'quiz' => BlockType.quiz,
        _ => BlockType.text,
      };
}

/// حالة تقدّم التلميذ في درس.
enum LessonStatus {
  notStarted('not_started', 'لم يبدأ'),
  inProgress('in_progress', 'قيد التقدم'),
  completed('completed', 'مكتمل');

  const LessonStatus(this.wire, this.label);

  final String wire;
  final String label;

  static LessonStatus fromWire(String? value) => switch (value) {
        'in_progress' => LessonStatus.inProgress,
        'completed' => LessonStatus.completed,
        _ => LessonStatus.notStarted,
      };
}

/// حالة تحميل درس أو ملف على الجهاز.
enum DownloadStatus {
  none('none', 'غير محمّل'),
  queued('queued', 'في الانتظار'),
  downloading('downloading', 'جارٍ التحميل'),
  completed('completed', 'محمّل'),
  failed('failed', 'فشل التحميل');

  const DownloadStatus(this.wire, this.label);

  final String wire;
  final String label;

  static DownloadStatus fromWire(String? value) => switch (value) {
        'queued' => DownloadStatus.queued,
        'downloading' => DownloadStatus.downloading,
        'completed' => DownloadStatus.completed,
        'failed' => DownloadStatus.failed,
        _ => DownloadStatus.none,
      };
}

/// حالة عملية في طابور الإرسال.
enum OutboxStatus {
  pending('pending'),
  failed('failed');

  const OutboxStatus(this.wire);

  final String wire;

  static OutboxStatus fromWire(String? value) =>
      value == 'failed' ? OutboxStatus.failed : OutboxStatus.pending;
}

/// نوع العملية المؤجَّلة في طابور الإرسال.
enum OutboxKind {
  /// تحديث تقدّم درس (dedup على مستوى الدرس).
  lessonProgress('lesson_progress'),

  /// إجابة كويز (لا تُدمج: كل محاولة تُرسل).
  quizAttempt('quiz_attempt'),

  /// اختيار/تغيير مستوى مادة.
  subjectLevel('subject_level');

  const OutboxKind(this.wire);

  final String wire;

  static OutboxKind fromWire(String value) => switch (value) {
        'quiz_attempt' => OutboxKind.quizAttempt,
        'subject_level' => OutboxKind.subjectLevel,
        _ => OutboxKind.lessonProgress,
      };
}
