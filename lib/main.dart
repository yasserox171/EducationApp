import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/config/env.dart';
import 'core/storage/app_database.dart';
import 'core/storage/secure_store.dart';
import 'core/utils/logger.dart';
import 'data/models/user.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) الإعدادات: BASE_URL وغيره من `.env` أو `--dart-define`.
  //    لا ينهار التطبيق إن كان الملف ناقصًا — يعرض شاشة «الإعداد غير مكتمل».
  await Env.load();

  // بيانات التواريخ العربية لـ `intl` (يستعملها `Formatters`).
  await initializeDateFormatting('ar');

  // 2) التخزين المحلي: قاعدة البيانات + الجلسة المحفوظة.
  final database = await AppDatabase.open();
  final secureStore = SecureStore();

  AuthSession? restoredSession;
  try {
    restoredSession = await secureStore.readSession();
  } catch (error) {
    Log.d('main', 'تعذّرت استعادة الجلسة: $error');
  }

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        secureStoreProvider.overrideWithValue(secureStore),
        initialSessionProvider.overrideWithValue(restoredSession),
      ],
      child: const EducationApp(),
    ),
  );
}
