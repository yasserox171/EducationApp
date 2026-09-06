import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/models/lesson_block.dart';
import '../../../data/models/teacher_stats.dart';

/// فقرات الدرس في وضع التحرير: تُسحب من الخادم دائمًا (لا نسخة محلية
/// قديمة) لأن الأستاذ يعدّل مصدر الحقيقة مباشرة.
final teacherBlocksProvider =
    FutureProvider.autoDispose.family<List<LessonBlock>, String>(
  (ref, lessonId) =>
      ref.watch(teacherRepositoryProvider).getBlocksForEditing(lessonId),
);

/// إحصائيات لوحة الأستاذ.
final teacherStatsProvider = FutureProvider.autoDispose<TeacherStats>(
  (ref) => ref.watch(teacherRepositoryProvider).fetchStats(),
);
