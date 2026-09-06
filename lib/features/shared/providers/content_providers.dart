import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/lesson.dart';
import '../../../data/models/lesson_block.dart';
import '../../../data/models/progress.dart';
import '../../../data/models/subject.dart';

/// مزوّدات القراءة المشتركة بين فضاءي الأستاذ والتلميذ.
///
/// كلها تمرّ عبر `ContentRepository` أي أنها offline-first تلقائيًا:
/// تُرجع النسخة المحلية فورًا وتحدّثها من الخادم عند توفّر الاتصال.

/// قائمة المواد. `ref.invalidate(subjectsProvider)` تكفي لإعادة التحميل.
final subjectsProvider = FutureProvider.autoDispose<List<Subject>>(
  (ref) => ref.watch(contentRepositoryProvider).getSubjects(),
);

/// دروس مادة معيّنة، مفلترة بالمستوى المختار (إن وُجد).
final lessonsProvider = FutureProvider.autoDispose
    .family<List<Lesson>, LessonsQuery>((ref, query) async {
  final repository = ref.watch(contentRepositoryProvider);
  return repository.getLessons(
    query.subjectId,
    level: query.level,
    publishedOnly: query.publishedOnly,
  );
});

class LessonsQuery {
  const LessonsQuery({
    required this.subjectId,
    this.level,
    this.publishedOnly = true,
  });

  final String subjectId;
  final LessonLevel? level;
  final bool publishedOnly;

  @override
  bool operator ==(Object other) =>
      other is LessonsQuery &&
      other.subjectId == subjectId &&
      other.level == level &&
      other.publishedOnly == publishedOnly;

  @override
  int get hashCode => Object.hash(subjectId, level, publishedOnly);
}

/// درس واحد بمعرّفه (من النسخة المحلية).
final lessonProvider = FutureProvider.autoDispose.family<Lesson?, String>(
  (ref, lessonId) => ref.watch(contentRepositoryProvider).getLesson(lessonId),
);

/// مادة واحدة بمعرّفها (من النسخة المحلية).
final subjectProvider = FutureProvider.autoDispose.family<Subject?, String>(
  (ref, subjectId) => ref.watch(contentRepositoryProvider).getSubject(subjectId),
);

/// فقرات درس (تعمل بدون إنترنت إن كان الدرس محمَّلًا).
final lessonBlocksProvider = FutureProvider.autoDispose
    .family<List<LessonBlock>, String>(
  (ref, lessonId) => ref.watch(contentRepositoryProvider).getBlocks(lessonId),
);

/// تقدّم درس واحد (لاستئناف المتابعة من آخر فقرة).
final lessonProgressProvider =
    FutureProvider.autoDispose.family<LessonProgress?, String>(
  (ref, lessonId) =>
      ref.watch(progressRepositoryProvider).getProgress(lessonId),
);

/// آخر إجابة لكل كويز في الدرس (لعرض النتيجة عند العودة للفقرة).
final lessonAttemptsProvider =
    FutureProvider.autoDispose.family<Map<String, QuizAttempt>, String>(
  (ref, lessonId) =>
      ref.watch(progressRepositoryProvider).attemptsForLesson(lessonId),
);

/// الطور الذي اختاره التلميذ لمادة (`null` يعني لم يختر بعد).
final subjectLevelProvider =
    FutureProvider.autoDispose.family<LessonLevel?, String>(
  (ref, subjectId) =>
      ref.watch(progressRepositoryProvider).getLevel(subjectId),
);

/// أطوار كل المواد دفعة واحدة (لشاشة الإعدادات).
final allLevelsProvider = FutureProvider.autoDispose<Map<String, LessonLevel>>(
  (ref) => ref.watch(progressRepositoryProvider).getAllLevels(),
);

/// تقدّم كل درس داخل مادة (لعرض «لم يبدأ / قيد التقدم / مكتمل»).
final subjectProgressProvider = FutureProvider.autoDispose
    .family<Map<String, LessonProgress>, String>(
  (ref, subjectId) =>
      ref.watch(progressRepositoryProvider).getProgressForSubject(subjectId),
);

/// ملخّص صفحة «تقدّمي».
final progressSummariesProvider =
    FutureProvider.autoDispose<List<SubjectProgressSummary>>(
  (ref) => ref.watch(progressRepositoryProvider).getSummaries(),
);
