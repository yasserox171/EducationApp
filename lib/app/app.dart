import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/ar_strings.dart';
import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';

/// جذر التطبيق: عربي + RTL كامل.
///
/// تحديد `locale: ar` يجعل Flutter يضبط اتجاه النص إلى RTL تلقائيًا في كل
/// الشجرة، فلا حاجة لتغليف الشاشات بـ `Directionality` يدويًا.
class EducationApp extends ConsumerWidget {
  const EducationApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: S.appName,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // نثبّت حجم الخط ضمن حدود معقولة حتى لا تنكسر الواجهة عند رفع
        // حجم الخط في إعدادات النظام.
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.3,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
