/// إحصائيات لوحة الأستاذ.
class TeacherStats {
  const TeacherStats({
    required this.studentsCount,
    required this.subjectsCount,
    required this.lessonsCount,
    required this.lessons,
    this.averageQuizScore,
  });

  final int studentsCount;
  final int subjectsCount;
  final int lessonsCount;

  /// متوسط نتائج الكويزات عبر كل الدروس (0.0 → 1.0).
  final double? averageQuizScore;

  final List<LessonStats> lessons;

  factory TeacherStats.fromJson(Map<String, dynamic> json) => TeacherStats(
        studentsCount: (json['students_count'] as num?)?.toInt() ?? 0,
        subjectsCount: (json['subjects_count'] as num?)?.toInt() ?? 0,
        lessonsCount: (json['lessons_count'] as num?)?.toInt() ?? 0,
        averageQuizScore: (json['average_quiz_score'] as num?)?.toDouble(),
        lessons: (json['lessons'] as List?)
                ?.whereType<Map>()
                .map((e) => LessonStats.fromJson(
                      Map<String, dynamic>.from(e),
                    ))
                .toList(growable: false) ??
            const <LessonStats>[],
      );

  static const empty = TeacherStats(
    studentsCount: 0,
    subjectsCount: 0,
    lessonsCount: 0,
    lessons: <LessonStats>[],
  );
}

/// إحصائيات درس واحد.
class LessonStats {
  const LessonStats({
    required this.lessonId,
    required this.lessonTitle,
    required this.subjectTitle,
    required this.completionRate,
    this.averageQuizScore,
    this.studentsStarted = 0,
    this.studentsCompleted = 0,
  });

  final String lessonId;
  final String lessonTitle;
  final String subjectTitle;

  /// نسبة إكمال الدرس (0.0 → 1.0).
  final double completionRate;
  final double? averageQuizScore;
  final int studentsStarted;
  final int studentsCompleted;

  factory LessonStats.fromJson(Map<String, dynamic> json) => LessonStats(
        lessonId: json['lesson_id'].toString(),
        lessonTitle: (json['lesson_title'] ?? '') as String,
        subjectTitle: (json['subject_title'] ?? '') as String,
        completionRate:
            ((json['completion_rate'] as num?)?.toDouble() ?? 0.0)
                .clamp(0.0, 1.0)
                .toDouble(),
        averageQuizScore: (json['average_quiz_score'] as num?)?.toDouble(),
        studentsStarted: (json['students_started'] as num?)?.toInt() ?? 0,
        studentsCompleted: (json['students_completed'] as num?)?.toInt() ?? 0,
      );
}
