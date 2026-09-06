/// مسارات التنقّل داخل التطبيق.
class Routes {
  const Routes._();

  static const String login = '/login';
  static const String configMissing = '/config-missing';

  // ------------------------------------------------------- فضاء التلميذ
  static const String studentHome = '/';
  static const String studentProgress = '/progress';
  static const String settings = '/settings';

  static const String subjectLessonsPattern = '/subjects/:subjectId';
  static const String lessonViewerPattern = '/lessons/:lessonId';

  static String subjectLessons(String subjectId) => '/subjects/$subjectId';

  static String lessonViewer(String lessonId) => '/lessons/$lessonId';

  // ------------------------------------------------------- فضاء الأستاذ
  static const String teacherHome = '/teacher';
  static const String teacherStats = '/teacher/stats';

  static const String teacherSubjectPattern = '/teacher/subjects/:subjectId';
  static const String teacherLessonEditorPattern = '/teacher/lessons/:lessonId';

  static String teacherSubject(String subjectId) =>
      '/teacher/subjects/$subjectId';

  static String teacherLessonEditor(String lessonId) =>
      '/teacher/lessons/$lessonId';

  static bool isTeacherRoute(String location) => location.startsWith('/teacher');
}
