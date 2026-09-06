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

/// فقرات درس (تعمل بدون إنترنت إن كان الدرس محمَّلًا).
final lessonBlocksProvider = FutureProvider.autoDispose
    .family<List<LessonBlock>, String>(
  (ref, lessonId) => ref.watch(contentRepositoryProvider).getBlocks(lessonId),
);

/// المستوى الذي اختاره التلميذ لمادة (`null` يعني لم يختر بعد).
final subjectLevelProvider =
    FutureProvider.autoDispose.family<LessonLevel?, String>(
  (ref, subjectId) =>
      ref.watch(progressRepositoryProvider).getLevel(subjectId),
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
