import 'enums.dart';

/// تقدّم التلميذ في درس واحد. يُخزَّن محليًا أولًا ثم يُرسل للخادم.
class LessonProgress {
  const LessonProgress({
    required this.lessonId,
    required this.subjectId,
    required this.status,
    this.lastBlockIndex = 0,
    this.blocksTotal = 0,
    this.completedAt,
    required this.updatedAt,
    this.isDirty = false,
  });

  final String lessonId;
  final String subjectId;
  final LessonStatus status;

  /// آخر فقرة وصل إليها التلميذ (لاستئناف المتابعة).
  final int lastBlockIndex;
  final int blocksTotal;
  final DateTime? completedAt;
  final DateTime updatedAt;

  /// `true` يعني وجود تغيير محلي لم يصل الخادم بعد.
  final bool isDirty;

  double get ratio {
    if (blocksTotal <= 0) return 0;
    final seen = (lastBlockIndex + 1).clamp(0, blocksTotal).toDouble();
    return seen / blocksTotal;
  }

  factory LessonProgress.initial({
    required String lessonId,
    required String subjectId,
    required int blocksTotal,
  }) =>
      LessonProgress(
        lessonId: lessonId,
        subjectId: subjectId,
        status: LessonStatus.notStarted,
        blocksTotal: blocksTotal,
        updatedAt: DateTime.now().toUtc(),
      );

  factory LessonProgress.fromJson(Map<String, dynamic> json) => LessonProgress(
        lessonId: json['lesson_id'].toString(),
        subjectId: json['subject_id'].toString(),
        status: LessonStatus.fromWire(json['status'] as String?),
        lastBlockIndex: (json['last_block_index'] as num?)?.toInt() ?? 0,
        blocksTotal: (json['blocks_total'] as num?)?.toInt() ?? 0,
        completedAt: DateTime.tryParse(json['completed_at']?.toString() ?? ''),
        updatedAt:
            DateTime.tryParse(json['updated_at']?.toString() ?? '')?.toUtc() ??
                DateTime.now().toUtc(),
      );

  Map<String, dynamic> toJson() => {
        'lesson_id': lessonId,
        'subject_id': subjectId,
        'status': status.wire,
        'last_block_index': lastBlockIndex,
        'blocks_total': blocksTotal,
        'completed_at': completedAt?.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Map<String, Object?> toDbRow() => {
        'lesson_id': lessonId,
        'subject_id': subjectId,
        'status': status.wire,
        'last_block_index': lastBlockIndex,
        'blocks_total': blocksTotal,
        'completed_at': completedAt?.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'is_dirty': isDirty ? 1 : 0,
      };

  factory LessonProgress.fromDbRow(Map<String, Object?> row) => LessonProgress(
        lessonId: row['lesson_id']! as String,
        subjectId: row['subject_id']! as String,
        status: LessonStatus.fromWire(row['status'] as String?),
        lastBlockIndex: (row['last_block_index'] as int?) ?? 0,
        blocksTotal: (row['blocks_total'] as int?) ?? 0,
        completedAt: DateTime.tryParse(row['completed_at'] as String? ?? ''),
        updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? '') ??
            DateTime.now().toUtc(),
        isDirty: (row['is_dirty'] as int?) == 1,
      );

  LessonProgress copyWith({
    LessonStatus? status,
    int? lastBlockIndex,
    int? blocksTotal,
    DateTime? completedAt,
    DateTime? updatedAt,
    bool? isDirty,
  }) =>
      LessonProgress(
        lessonId: lessonId,
        subjectId: subjectId,
        status: status ?? this.status,
        lastBlockIndex: lastBlockIndex ?? this.lastBlockIndex,
        blocksTotal: blocksTotal ?? this.blocksTotal,
        completedAt: completedAt ?? this.completedAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isDirty: isDirty ?? this.isDirty,
      );
}

/// محاولة إجابة على كويز.
class QuizAttempt {
  const QuizAttempt({
    required this.id,
    required this.blockId,
    required this.lessonId,
    required this.selectedOptionId,
    required this.isCorrect,
    required this.answeredAt,
    this.isDirty = true,
  });

  /// معرّف محلي (UUID) يُستعمل كمفتاح idempotency عند الإرسال للخادم.
  final String id;
  final String blockId;
  final String lessonId;
  final String selectedOptionId;
  final bool isCorrect;
  final DateTime answeredAt;
  final bool isDirty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'block_id': blockId,
        'lesson_id': lessonId,
        'selected_option_id': selectedOptionId,
        'is_correct': isCorrect,
        'answered_at': answeredAt.toIso8601String(),
      };

  Map<String, Object?> toDbRow() => {
        'id': id,
        'block_id': blockId,
        'lesson_id': lessonId,
        'selected_option_id': selectedOptionId,
        'is_correct': isCorrect ? 1 : 0,
        'answered_at': answeredAt.toIso8601String(),
        'is_dirty': isDirty ? 1 : 0,
      };

  factory QuizAttempt.fromDbRow(Map<String, Object?> row) => QuizAttempt(
        id: row['id']! as String,
        blockId: row['block_id']! as String,
        lessonId: row['lesson_id']! as String,
        selectedOptionId: row['selected_option_id']! as String,
        isCorrect: (row['is_correct'] as int?) == 1,
        answeredAt: DateTime.tryParse(row['answered_at'] as String? ?? '') ??
            DateTime.now().toUtc(),
        isDirty: (row['is_dirty'] as int?) == 1,
      );
}

/// المستوى الذي اختاره التلميذ لمادة معيّنة.
class SubjectLevelChoice {
  const SubjectLevelChoice({
    required this.subjectId,
    required this.level,
    required this.updatedAt,
    this.isDirty = false,
  });

  final String subjectId;
  final LessonLevel level;
  final DateTime updatedAt;
  final bool isDirty;

  Map<String, dynamic> toJson() => {
        'subject_id': subjectId,
        'level': level.wire,
        'updated_at': updatedAt.toIso8601String(),
      };

  Map<String, Object?> toDbRow() => {
        'subject_id': subjectId,
        'level': level.wire,
        'updated_at': updatedAt.toIso8601String(),
        'is_dirty': isDirty ? 1 : 0,
      };

  factory SubjectLevelChoice.fromDbRow(Map<String, Object?> row) =>
      SubjectLevelChoice(
        subjectId: row['subject_id']! as String,
        level: LessonLevel.fromWire(row['level'] as String?),
        updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? '') ??
            DateTime.now().toUtc(),
        isDirty: (row['is_dirty'] as int?) == 1,
      );

  factory SubjectLevelChoice.fromJson(Map<String, dynamic> json) =>
      SubjectLevelChoice(
        subjectId: json['subject_id'].toString(),
        level: LessonLevel.fromWire(json['level'] as String?),
        updatedAt:
            DateTime.tryParse(json['updated_at']?.toString() ?? '')?.toUtc() ??
                DateTime.now().toUtc(),
      );
}

/// ملخّص تقدّم مادة واحدة (لصفحة «تقدّمي»).
class SubjectProgressSummary {
  const SubjectProgressSummary({
    required this.subjectId,
    required this.subjectTitle,
    required this.totalLessons,
    required this.completedLessons,
    required this.inProgressLessons,
  });

  final String subjectId;
  final String subjectTitle;
  final int totalLessons;
  final int completedLessons;
  final int inProgressLessons;

  double get ratio => totalLessons == 0 ? 0 : completedLessons / totalLessons;
}
