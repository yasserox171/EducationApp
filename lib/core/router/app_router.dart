import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/shared/config_missing_screen.dart';
import '../../features/shared/placeholder_screen.dart';
import '../../features/student/presentation/lesson_viewer_screen.dart';
import '../../features/student/presentation/progress_screen.dart';
import '../../features/student/presentation/settings_screen.dart';
import '../../features/student/presentation/student_home_screen.dart';
import '../../features/student/presentation/subject_lessons_screen.dart';
import '../../features/teacher/presentation/lesson_editor_screen.dart';
import '../../features/teacher/presentation/teacher_home_screen.dart';
import '../../features/teacher/presentation/teacher_stats_screen.dart';
import '../../features/teacher/presentation/teacher_subject_screen.dart';
import '../config/env.dart';
import '../l10n/ar_strings.dart';
import 'route_paths.dart';

/// الموجّه. يعيد التحويل تلقائيًا حسب حالة الدخول ودور المستخدم:
/// * إعداد ناقص  → شاشة الإعداد.
/// * غير مسجّل   → شاشة الدخول.
/// * أستاذ       → `/teacher`.
/// * تلميذ       → `/`.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(authControllerProvider, (_, __) => refresh.value++);

  return GoRouter(
    initialLocation: Routes.studentHome,
    refreshListenable: refresh,
    debugLogDiagnostics: kDebugMode,
    redirect: (context, state) {
      final location = state.matchedLocation;

      if (!Env.isConfigured) {
        return location == Routes.configMissing ? null : Routes.configMissing;
      }
      if (location == Routes.configMissing) {
        return Routes.studentHome;
      }

      final auth = ref.read(authControllerProvider);
      final isLoginRoute = location == Routes.login;

      if (!auth.isAuthenticated) {
        return isLoginRoute ? null : Routes.login;
      }

      final home = auth.isTeacher ? Routes.teacherHome : Routes.studentHome;
      if (isLoginRoute) return home;

      // كل دور في فضائه: لا يدخل التلميذ مسارات الأستاذ ولا العكس.
      // الإعدادات مشتركة بين الدورين.
      final isTeacherRoute = Routes.isTeacherRoute(location);
      if (auth.isTeacher && !isTeacherRoute && location != Routes.settings) {
        return Routes.teacherHome;
      }
      if (!auth.isTeacher && isTeacherRoute) {
        return Routes.studentHome;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.configMissing,
        builder: (context, state) => const ConfigMissingScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),

      // ------------------------------------------------------ التلميذ
      GoRoute(
        path: Routes.studentHome,
        builder: (context, state) => const StudentHomeScreen(),
      ),
      GoRoute(
        path: Routes.subjectLessonsPattern,
        builder: (context, state) => SubjectLessonsScreen(
          subjectId: state.pathParameters['subjectId']!,
        ),
      ),
      GoRoute(
        path: Routes.lessonViewerPattern,
        builder: (context, state) => LessonViewerScreen(
          lessonId: state.pathParameters['lessonId']!,
        ),
      ),
      GoRoute(
        path: Routes.studentProgress,
        builder: (context, state) => const ProgressScreen(),
      ),

      // ------------------------------------------------------- الأستاذ
      GoRoute(
        path: Routes.teacherHome,
        builder: (context, state) => const TeacherHomeScreen(),
      ),
      GoRoute(
        path: Routes.teacherStats,
        builder: (context, state) => const TeacherStatsScreen(),
      ),
      GoRoute(
        path: Routes.teacherSubjectPattern,
        builder: (context, state) => TeacherSubjectScreen(
          subjectId: state.pathParameters['subjectId']!,
        ),
      ),
      GoRoute(
        path: Routes.teacherLessonEditorPattern,
        builder: (context, state) => LessonEditorScreen(
          lessonId: state.pathParameters['lessonId']!,
        ),
      ),
    ],
    errorBuilder: (context, state) => PlaceholderScreen(
      title: S.appName,
      note: 'المسار غير موجود: ${state.uri}',
    ),
  );
});
