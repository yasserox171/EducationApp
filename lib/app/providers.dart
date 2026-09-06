import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/env.dart';
import '../core/network/api_client.dart';
import '../core/network/network_info.dart';
import '../core/storage/app_database.dart';
import '../core/storage/dao/content_dao.dart';
import '../core/storage/dao/download_dao.dart';
import '../core/storage/dao/kv_dao.dart';
import '../core/storage/dao/outbox_dao.dart';
import '../core/storage/dao/progress_dao.dart';
import '../core/storage/media_store.dart';
import '../core/storage/secure_store.dart';
import '../data/models/user.dart';
import '../data/remote/auth_api.dart';
import '../data/remote/content_api.dart';
import '../data/remote/progress_api.dart';
import '../data/remote/stats_api.dart';
import '../data/demo/demo_api_client.dart';
import '../data/remote/upload_api.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/content_repository.dart';
import '../data/repositories/download_repository.dart';
import '../data/repositories/progress_repository.dart';
import '../data/repositories/teacher_repository.dart';
import '../data/sync/sync_service.dart';

/// حامل الجلسة: يكسر التبعية الدائرية بين `ApiClient` و`AuthController`.
///
/// `ApiClient` يحتاج الرمز لكل طلب، و`AuthController` يحتاج `ApiClient`
/// لتسجيل الدخول. الحل: كلاهما يعرف هذا الحامل البسيط فقط.
class SessionHolder {
  String? token;

  /// يسجّلها `AuthController` ليُستدعى عند رد 401 من أي طلب.
  void Function()? onSessionExpired;
}

// ------------------------------------------------------------- البنية التحتية

/// يُتجاوَز في `main()` بعد فتح قاعدة البيانات.
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('appDatabaseProvider يجب تجاوزه في main()'),
);

/// الجلسة المستعادة عند الإقلاع — يُتجاوَز في `main()`.
final initialSessionProvider = Provider<AuthSession?>((ref) => null);

final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore());

final mediaStoreProvider = Provider<MediaStore>((ref) => MediaStore());

final networkInfoProvider =
    Provider<NetworkInfo>((ref) => NetworkInfo(alwaysOnline: Env.demoMode));

final sessionHolderProvider = Provider<SessionHolder>((ref) => SessionHolder());

/// حالة الاتصال الحيّة (تُستعمل لشارة «أنت غير متصل» في الواجهة).
final connectivityProvider = StreamProvider<bool>(
  (ref) => ref.watch(networkInfoProvider).onStatusChange,
);

final apiClientProvider = Provider<ApiClient>((ref) {
  // وضع التجربة: خادم وهمي في الذاكرة بدل أي اتصال بالشبكة.
  if (Env.demoMode) return DemoApiClient();

  final holder = ref.watch(sessionHolderProvider);
  return ApiClient.create(
    tokenProvider: () => holder.token,
    onUnauthorized: () => holder.onSessionExpired?.call(),
  );
});

// -------------------------------------------------------------------- DAOs

final contentDaoProvider =
    Provider<ContentDao>((ref) => ContentDao(ref.watch(appDatabaseProvider)));

final progressDaoProvider =
    Provider<ProgressDao>((ref) => ProgressDao(ref.watch(appDatabaseProvider)));

final downloadDaoProvider =
    Provider<DownloadDao>((ref) => DownloadDao(ref.watch(appDatabaseProvider)));

final outboxDaoProvider =
    Provider<OutboxDao>((ref) => OutboxDao(ref.watch(appDatabaseProvider)));

final kvDaoProvider =
    Provider<KvDao>((ref) => KvDao(ref.watch(appDatabaseProvider)));

// ------------------------------------------------------------ خدمات الشبكة

final authApiProvider =
    Provider<AuthApi>((ref) => AuthApi(ref.watch(apiClientProvider)));

final contentApiProvider =
    Provider<ContentApi>((ref) => ContentApi(ref.watch(apiClientProvider)));

final uploadApiProvider =
    Provider<UploadApi>((ref) => UploadApi(ref.watch(apiClientProvider)));

final progressApiProvider =
    Provider<ProgressApi>((ref) => ProgressApi(ref.watch(apiClientProvider)));

final statsApiProvider =
    Provider<StatsApi>((ref) => StatsApi(ref.watch(apiClientProvider)));

// ---------------------------------------------------------------- المستودعات

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    api: ref.watch(authApiProvider),
    secureStore: ref.watch(secureStoreProvider),
    database: ref.watch(appDatabaseProvider),
    mediaStore: ref.watch(mediaStoreProvider),
  ),
);

final contentRepositoryProvider = Provider<ContentRepository>(
  (ref) => ContentRepository(
    api: ref.watch(contentApiProvider),
    dao: ref.watch(contentDaoProvider),
    kv: ref.watch(kvDaoProvider),
    networkInfo: ref.watch(networkInfoProvider),
  ),
);

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => ProgressRepository(
    dao: ref.watch(progressDaoProvider),
    outbox: ref.watch(outboxDaoProvider),
  ),
);

final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  final repository = DownloadRepository(
    contentRepository: ref.watch(contentRepositoryProvider),
    dao: ref.watch(downloadDaoProvider),
    mediaStore: ref.watch(mediaStoreProvider),
    networkInfo: ref.watch(networkInfoProvider),
    dio: ref.watch(apiClientProvider).dio,
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final teacherRepositoryProvider = Provider<TeacherRepository>(
  (ref) => TeacherRepository(
    contentApi: ref.watch(contentApiProvider),
    uploadApi: ref.watch(uploadApiProvider),
    statsApi: ref.watch(statsApiProvider),
    dao: ref.watch(contentDaoProvider),
    networkInfo: ref.watch(networkInfoProvider),
    isDemo: Env.demoMode,
  ),
);

// ------------------------------------------------------------------ المزامنة

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(
    outboxDao: ref.watch(outboxDaoProvider),
    progressDao: ref.watch(progressDaoProvider),
    kvDao: ref.watch(kvDaoProvider),
    progressApi: ref.watch(progressApiProvider),
    contentRepository: ref.watch(contentRepositoryProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// حالة المزامنة للعرض في الواجهة.
final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final service = ref.watch(syncServiceProvider);
  return service.statusStream;
});
