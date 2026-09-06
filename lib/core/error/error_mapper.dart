import 'dart:io';

import 'package:dio/dio.dart';

import 'app_exception.dart';

/// يحوّل أخطاء Dio / النظام إلى [AppException] برسائل عربية.
class ErrorMapper {
  const ErrorMapper._();

  static AppException fromDio(DioException error) {
    // خطأ سبق تحويله في اعتراض (interceptor).
    final wrapped = error.error;
    if (wrapped is AppException) return wrapped;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return RequestTimeoutException(details: error.message);
      case DioExceptionType.connectionError:
        return NetworkException(details: error.message);
      case DioExceptionType.cancel:
        return const UnknownException(message: 'تم إلغاء الطلب.');
      case DioExceptionType.badCertificate:
        return NetworkException(
          message: 'تعذّر التحقق من شهادة الخادم.',
          details: error.message,
        );
      case DioExceptionType.badResponse:
        return _fromResponse(error.response);
      case DioExceptionType.unknown:
        if (wrapped is SocketException) {
          return NetworkException(details: wrapped.message);
        }
        return UnknownException(details: error.message ?? wrapped?.toString());
    }
  }

  static AppException _fromResponse(Response<dynamic>? response) {
    final status = response?.statusCode ?? 0;
    final serverMessage = _extractMessage(response?.data);

    if (status == 401) {
      return UnauthorizedException(details: serverMessage);
    }
    if (status == 403) {
      return ForbiddenException(details: serverMessage);
    }
    if (status == 404) {
      return NotFoundException(details: serverMessage);
    }
    if (status == 400 || status == 422) {
      return ValidationException(
        message: serverMessage ?? 'البيانات المُدخلة غير صحيحة.',
        fieldErrors: _extractFieldErrors(response?.data),
        statusCode: status,
      );
    }
    if (status == 413) {
      return const ValidationException(
        message: 'حجم الملف أكبر من المسموح به على الخادم.',
        statusCode: 413,
      );
    }
    if (status >= 500) {
      return ServerException(statusCode: status, details: serverMessage);
    }
    return UnknownException(details: 'HTTP $status — $serverMessage');
  }

  /// يقرأ رسالة الخطأ من الأشكال الشائعة:
  /// `{"message": "..."}` أو `{"error": "..."}` أو `{"detail": "..."}`.
  static String? _extractMessage(dynamic data) {
    if (data is Map) {
      for (final key in const ['message', 'error', 'detail', 'msg']) {
        final value = data[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
    }
    if (data is String && data.trim().isNotEmpty && data.length < 300) {
      return data.trim();
    }
    return null;
  }

  /// يقرأ `{"errors": {"email": ["..."]}}` أو `{"errors": {"email": "..."}}`.
  static Map<String, String> _extractFieldErrors(dynamic data) {
    if (data is! Map) return const {};
    final errors = data['errors'];
    if (errors is! Map) return const {};

    final result = <String, String>{};
    errors.forEach((key, value) {
      if (key is! String) return;
      if (value is String) {
        result[key] = value;
      } else if (value is List && value.isNotEmpty) {
        result[key] = value.first.toString();
      }
    });
    return result;
  }

  /// يحوّل أي خطأ غير متوقع إلى [AppException].
  static AppException fromAny(Object error, [StackTrace? stackTrace]) {
    if (error is AppException) return error;
    if (error is DioException) return fromDio(error);
    if (error is SocketException) return NetworkException(details: error.message);
    if (error is FileSystemException) {
      return CacheException(details: error.message);
    }
    return UnknownException(details: error.toString());
  }
}
