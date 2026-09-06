import 'package:dio/dio.dart';

/// يضيف ترويسة `Authorization` لكل طلب، ويبلّغ التطبيق عند انتهاء الجلسة.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.tokenProvider,
    required this.onUnauthorized,
  });

  /// يُرجع الرمز الحالي أو `null` إن لم يسجّل المستخدم الدخول.
  final String? Function() tokenProvider;

  /// يُستدعى مرة واحدة عند أول 401 — يقوم بتسجيل الخروج وتحويل المستخدم
  /// إلى شاشة الدخول.
  final void Function() onUnauthorized;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    final token = tokenProvider();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    options.headers['Accept'] = 'application/json';
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final status = err.response?.statusCode;
    final isLoginRequest = err.requestOptions.path.contains('/auth/login');
    if (status == 401 && !isLoginRequest) {
      onUnauthorized();
    }
    handler.next(err);
  }
}
