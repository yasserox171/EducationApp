/// مسارات الـ API. تُضاف إلى `BASE_URL` القادم من `.env`.
/// التفاصيل الكاملة (شكل الطلب والرد) موثّقة في `docs/API_CONTRACT.md`.
class ApiEndpoints {
  const ApiEndpoints._();

  // ---------------------------------------------------------- المصادقة
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';

  // ------------------------------------------------------------ المحتوى
  static const String subjects = '/subjects';

  static String subject(String id) => '/subjects/$id';

  static String subjectLessons(String subjectId) => '/subjects/$subjectId/lessons';

  static const String lessons = '/lessons';

  static String lesson(String id) => '/lessons/$id';

  static String lessonBlocks(String lessonId) => '/lessons/$lessonId/blocks';

  static String lessonBlocksReorder(String lessonId) =>
      '/lessons/$lessonId/blocks/reorder';

  static String block(String id) => '/blocks/$id';

  static String subjectLessonsReorder(String subjectId) =>
      '/subjects/$subjectId/lessons/reorder';

  // -------------------------------------------------------------- الرفع
  static const String uploadVideo = '/uploads/video';

  /// رفع مرفق PDF لفقرة فيديو (multipart).
  static String blockAttachments(String blockId) =>
      '/blocks/$blockId/attachments';

  static String attachment(String attachmentId) =>
      '/attachments/$attachmentId';

  // ------------------------------------------------------------- التقدّم
  static const String myProgress = '/me/progress';
  static const String progressSync = '/me/progress/sync';
  static const String quizAttempts = '/me/quiz-attempts';
  static const String myLevels = '/me/levels';

  static String subjectLevel(String subjectId) => '/me/levels/$subjectId';

  // --------------------------------------------------------- الإحصائيات
  static const String teacherStats = '/teacher/stats';
}
