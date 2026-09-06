import '../../core/config/app_constants.dart';
import '../../core/error/app_exception.dart';
import '../../core/network/network_info.dart';
import '../../core/storage/dao/content_dao.dart';
import '../../core/storage/dao/kv_dao.dart';
import '../../core/utils/logger.dart';
import '../models/enums.dart';
import '../models/lesson.dart';
import '../models/lesson_block.dart';
import '../models/subject.dart';
import '../remote/content_api.dart';

/// قراءة المحتوى بنمط offline-first.
///
/// القاعدة في كل دالة:
/// 1. اقرأ من قاعدة البيانات المحلية.
/// 2. إن كان هناك اتصال والبيانات قديمة (أو التحديث مطلوب صراحة) اسحب من
///    الخادم واستبدل النسخة المحلية.
/// 3. إن فشل الطلب ووُجدت نسخة محلية، أعِدها بصمت — التطبيق يبقى شغّالًا.
/// 4. إن فشل الطلب ولا توجد نسخة محلية، ارمِ الخطأ لتعرضه الواجهة.
///
/// التحميل الفعلي للفيديوهات لا يحدث هنا أبدًا: هو يدوي بالكامل عبر
/// `DownloadRepository` بضغطة زر «تحميل».
class ContentRepository {
  ContentRepository({
    required ContentApi api,
    required ContentDao dao,
    required KvDao kv,
    required NetworkInfo networkInfo,
  })  : _api = api,
        _dao = dao,
        _kv = kv,
        _networkInfo = networkInfo;

  final ContentApi _api;
  final ContentDao _dao;
  final KvDao _kv;
  final NetworkInfo _networkInfo;

  static const String _subjectsSyncKey = 'sync:subjects';

  String _lessonsSyncKey(String subjectId) => 'sync:lessons:$subjectId';

  // ------------------------------------------------------------- المواد

  Future<List<Subject>> getSubjects({bool forceRefresh = false}) async {
    final local = await _dao.getSubjects();
    final shouldFetch = forceRefresh ||
        local.isEmpty ||
        await _isStale(_subjectsSyncKey);

    if (!shouldFetch || !await _networkInfo.isOnline) return local;

    try {
      final remote = await _api.fetchSubjects();
      await _dao.replaceSubjects(remote);
      await _kv.setDateTime(_subjectsSyncKey, DateTime.now().toUtc());
      return remote;
    } on AppException catch (error) {
      if (local.isNotEmpty) {
        Log.d(
          'ContentRepository',
          'فشل تحديث المواد، عرض النسخة المحلية: ${error.message}',
        );
        return local;
      }
      rethrow;
    }
  }

  Future<Subject?> getSubject(String id) => _dao.getSubject(id);

  // ------------------------------------------------------------- الدروس

  Future<List<Lesson>> getLessons(
    String subjectId, {
    LessonLevel? level,
    bool publishedOnly = true,
    bool forceRefresh = false,
  }) async {
    final local = await _dao.getLessons(
      subjectId: subjectId,
      level: level,
      publishedOnly: publishedOnly,
    );
    final shouldFetch = forceRefresh ||
        local.isEmpty ||
        await _isStale(_lessonsSyncKey(subjectId));

    if (!shouldFetch || !await _networkInfo.isOnline) return local;

    try {
      // نسحب كل الأطوار ونفلتر محليًا: هكذا يستطيع التلميذ تغيير طوره
      // من الإعدادات دون الحاجة لاتصال جديد.
      final remote = await _api.fetchLessons(subjectId);
      await _dao.replaceLessonsOfSubject(subjectId, remote);
      await _kv.setDateTime(_lessonsSyncKey(subjectId), DateTime.now().toUtc());
      return await _dao.getLessons(
        subjectId: subjectId,
        level: level,
        publishedOnly: publishedOnly,
      );
    } on AppException catch (error) {
      if (local.isNotEmpty) {
        Log.d(
          'ContentRepository',
          'فشل تحديث الدروس، عرض النسخة المحلية: ${error.message}',
        );
        return local;
      }
      rethrow;
    }
  }

  Future<Lesson?> getLesson(String id) => _dao.getLesson(id);

  // ------------------------------------------------------------ الفقرات

  /// فقرات الدرس. إن كانت مخزَّنة محليًا تعمل بدون إنترنت.
  Future<List<LessonBlock>> getBlocks(
    String lessonId, {
    bool forceRefresh = false,
  }) async {
    final local = await _dao.getBlocks(lessonId);
    final cachedAt = await _dao.blocksCachedAt(lessonId);
    final isStale = cachedAt == null ||
        DateTime.now().toUtc().difference(cachedAt) >
            AppConstants.contentStaleAfter;
    final shouldFetch = forceRefresh || local.isEmpty || isStale;

    if (!shouldFetch) return local;

    if (!await _networkInfo.isOnline) {
      if (local.isNotEmpty) return local;
      throw const OfflineContentException();
    }

    try {
      final remote = await _api.fetchBlocks(lessonId);
      await _dao.replaceBlocks(lessonId, remote);
      return remote;
    } on AppException catch (error) {
      if (local.isNotEmpty) {
        Log.d(
          'ContentRepository',
          'فشل تحديث الفقرات، عرض النسخة المحلية: ${error.message}',
        );
        return local;
      }
      rethrow;
    }
  }

  /// هل يمكن فتح هذا الدرس بدون إنترنت؟
  Future<bool> isAvailableOffline(String lessonId) => _dao.hasBlocks(lessonId);

  /// مزامنة خفيفة عند فتح التطبيق: تحدّث قوائم المواد والدروس فقط،
  /// ولا تلمس الفيديوهات.
  Future<void> refreshCatalog() async {
    if (!await _networkInfo.isOnline) return;
    final subjects = await getSubjects(forceRefresh: true);
    for (final subject in subjects) {
      try {
        await getLessons(subject.id, publishedOnly: false, forceRefresh: true);
      } on AppException catch (error) {
        Log.d(
          'ContentRepository',
          'تعذّر تحديث دروس ${subject.id}: ${error.message}',
        );
      }
    }
    await _kv.setDateTime(KvDao.lastContentSyncAt, DateTime.now().toUtc());
  }

  Future<bool> _isStale(String key) async {
    final last = await _kv.getDateTime(key);
    if (last == null) return true;
    return DateTime.now().toUtc().difference(last) >
        AppConstants.contentStaleAfter;
  }
}
