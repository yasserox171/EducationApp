import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/models/download_state.dart';

/// حالة تحميل درس: القيمة الحالية من قاعدة البيانات ثم التحديثات الحيّة
/// من مدير التحميل (شريط التقدم).
final lessonDownloadProvider =
    StreamProvider.autoDispose.family<LessonDownload, String>(
  (ref, lessonId) async* {
    final repository = ref.watch(downloadRepositoryProvider);
    yield await repository.status(lessonId);
    yield* repository.watch(lessonId);
  },
);

/// المسار المحلي لفيديو فقرة (`null` = غير محمَّل، شغّله من الشبكة).
final localVideoPathProvider =
    FutureProvider.autoDispose.family<String?, String>(
  (ref, blockId) => ref.watch(downloadRepositoryProvider).localPathFor(blockId),
);

/// إجمالي المساحة التي تشغلها الدروس المحمَّلة.
final usedStorageProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(downloadRepositoryProvider).usedBytes(),
);
