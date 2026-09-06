import '../../core/error/app_exception.dart';
import '../../core/storage/app_database.dart';
import '../../core/storage/media_store.dart';
import '../../core/storage/secure_store.dart';
import '../../core/utils/logger.dart';
import '../models/user.dart';
import '../remote/auth_api.dart';

/// المصادقة: تسجيل الدخول/الخروج، وحفظ الجلسة في التخزين الآمن.
///
/// لا يوجد تسجيل ذاتي في هذه النسخة: حسابات التلاميذ يُنشئها الأستاذ من
/// الباك-اند.
class AuthRepository {
  AuthRepository({
    required AuthApi api,
    required SecureStore secureStore,
    required AppDatabase database,
    required MediaStore mediaStore,
  })  : _api = api,
        _secureStore = secureStore,
        _database = database,
        _mediaStore = mediaStore;

  final AuthApi _api;
  final SecureStore _secureStore;
  final AppDatabase _database;
  final MediaStore _mediaStore;

  Future<AuthSession?> restoreSession() => _secureStore.readSession();

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || password.isEmpty) {
      throw const ValidationException(
        message: 'أدخل البريد الإلكتروني وكلمة السر.',
      );
    }

    final session = await _api.login(
      email: normalizedEmail,
      password: password,
    );

    if (session.token.isEmpty) {
      throw const ServerException(message: 'لم يُرجع الخادم رمز الدخول.');
    }

    // مستخدم مختلف على نفس الجهاز → نمسح بيانات السابق قبل أي شيء.
    final previous = await _secureStore.readSession();
    if (previous != null && previous.user.id != session.user.id) {
      await _clearLocalData();
    }

    await _secureStore.writeSession(session);
    return session;
  }

  /// تسجيل الخروج: يمسح الجلسة والبيانات المحلية والملفات المحمَّلة.
  /// يتم دائمًا حتى لو فشل إبلاغ الخادم.
  Future<void> logout({bool wipeDownloads = true}) async {
    try {
      await _api.logout();
    } catch (error) {
      Log.d('AuthRepository', 'تعذّر إبلاغ الخادم بالخروج: $error');
    }
    await _secureStore.clearSession();
    await _clearLocalData(wipeDownloads: wipeDownloads);
  }

  Future<void> _clearLocalData({bool wipeDownloads = true}) async {
    await _database.wipeUserData();
    if (wipeDownloads) {
      try {
        await _mediaStore.clearAll();
      } catch (error) {
        Log.d('AuthRepository', 'تعذّر حذف الملفات المحمَّلة: $error');
      }
    }
  }

  /// تحديث بيانات المستخدم من الخادم (يُستدعى عند الإقلاع مع اتصال).
  Future<AppUser?> refreshUser() async {
    final session = await _secureStore.readSession();
    if (session == null) return null;
    final user = await _api.me();
    await _secureStore.writeSession(
      AuthSession(token: session.token, user: user),
    );
    return user;
  }
}
