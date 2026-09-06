import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/error/app_exception.dart';
import '../../core/error/error_mapper.dart';
import '../../core/utils/logger.dart';
import '../../data/models/user.dart';

enum AuthStatus { authenticated, unauthenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.isSubmitting = false,
    this.errorMessage,
    this.sessionExpired = false,
  });

  final AuthStatus status;
  final AppUser? user;
  final bool isSubmitting;
  final String? errorMessage;

  /// `true` عندما انتهت الجلسة من الخادم (401) وليس بخروج إرادي.
  final bool sessionExpired;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isTeacher => user?.isTeacher ?? false;
  bool get isStudent => user?.isStudent ?? false;

  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    bool? sessionExpired,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: status == AuthStatus.unauthenticated ? null : (user ?? this.user),
        isSubmitting: isSubmitting ?? this.isSubmitting,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        sessionExpired: sessionExpired ?? this.sessionExpired,
      );
}

/// مصدر الحقيقة لحالة الدخول. الموجّه (`GoRouter`) يستمع إليه لتحويل
/// المستخدم بين شاشة الدخول وفضائه (أستاذ/تلميذ).
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final holder = ref.read(sessionHolderProvider);
    final restored = ref.read(initialSessionProvider);

    holder
      ..token = restored?.token
      ..onSessionExpired = _handleSessionExpired;

    if (restored == null) {
      return const AuthState(status: AuthStatus.unauthenticated);
    }

    // جلسة مستعادة: نبدأ المزامنة في الخلفية دون انتظار.
    scheduleMicrotask(_startSync);
    return AuthState(status: AuthStatus.authenticated, user: restored.user);
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final session = await ref
          .read(authRepositoryProvider)
          .login(email: email, password: password);

      ref.read(sessionHolderProvider).token = session.token;
      state = AuthState(status: AuthStatus.authenticated, user: session.user);
      unawaited(_startSync());
      return true;
    } on AppException catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: _loginMessage(error),
      );
      return false;
    } catch (error, stackTrace) {
      final mapped = ErrorMapper.fromAny(error, stackTrace);
      state = state.copyWith(isSubmitting: false, errorMessage: mapped.message);
      return false;
    }
  }

  /// رسالة أوضح للحالة الأشيع: بريد أو كلمة سر خاطئة.
  static String _loginMessage(AppException error) =>
      error is UnauthorizedException
          ? 'البريد الإلكتروني أو كلمة السر غير صحيحة.'
          : error.message;

  Future<void> logout() async {
    await ref.read(syncServiceProvider).stop();
    try {
      await ref.read(authRepositoryProvider).logout();
    } catch (error) {
      Log.d('AuthController', 'خطأ أثناء الخروج: $error');
    }
    ref.read(sessionHolderProvider).token = null;
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// انتهاء الجلسة من طرف الخادم (401).
  void _handleSessionExpired() {
    if (!state.isAuthenticated) return;
    ref.read(sessionHolderProvider).token = null;
    unawaited(ref.read(syncServiceProvider).stop());
    // لا نمسح البيانات المحلية هنا: التلميذ قد يكون لديه تقدّم لم يُرسل بعد،
    // وسيُرسل بمجرّد تسجيل الدخول من جديد.
    state = const AuthState(
      status: AuthStatus.unauthenticated,
      sessionExpired: true,
    );
  }

  void clearError() => state = state.copyWith(clearError: true);

  Future<void> _startSync() async {
    try {
      await ref.read(downloadRepositoryProvider).reconcileOnStartup();
      await ref.read(syncServiceProvider).start();
    } catch (error) {
      Log.d('AuthController', 'تعذّر بدء المزامنة: $error');
    }
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
