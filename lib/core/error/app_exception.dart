/// استثناءات التطبيق: كل استثناء يحمل رسالة عربية جاهزة للعرض للمستخدم.
///
/// طبقة البيانات ترمي هذه الأنواع فقط، وطبقة العرض تعرض `message` مباشرة
/// دون الحاجة لمعرفة تفاصيل Dio أو sqflite.
sealed class AppException implements Exception {
  const AppException(this.message, {this.details, this.statusCode});

  /// رسالة عربية موجّهة للمستخدم.
  final String message;

  /// تفاصيل تقنية للتسجيل فقط (لا تُعرض).
  final String? details;

  final int? statusCode;

  @override
  String toString() =>
      '$runtimeType(status: $statusCode, message: $message, details: $details)';
}

/// لا يوجد اتصال بالإنترنت، أو تعذّر الوصول للخادم.
class NetworkException extends AppException {
  const NetworkException({
    String message = 'لا يوجد اتصال بالإنترنت. تحقّق من الشبكة ثم أعد المحاولة.',
    super.details,
  }) : super(message);
}

/// انتهت مهلة الطلب.
class RequestTimeoutException extends AppException {
  const RequestTimeoutException({
    String message = 'استغرق الطلب وقتًا طويلًا. أعد المحاولة لاحقًا.',
    super.details,
  }) : super(message);
}

/// الجلسة منتهية أو بيانات الدخول خاطئة (401).
class UnauthorizedException extends AppException {
  const UnauthorizedException({
    String message = 'انتهت الجلسة. الرجاء تسجيل الدخول من جديد.',
    super.details,
  }) : super(message, statusCode: 401);
}

/// لا تملك صلاحية هذا الإجراء (403).
class ForbiddenException extends AppException {
  const ForbiddenException({
    String message = 'لا تملك صلاحية للقيام بهذا الإجراء.',
    super.details,
  }) : super(message, statusCode: 403);
}

/// العنصر غير موجود (404).
class NotFoundException extends AppException {
  const NotFoundException({
    String message = 'العنصر المطلوب غير موجود.',
    super.details,
  }) : super(message, statusCode: 404);
}

/// بيانات مرسلة غير صالحة (422/400)، مع أخطاء الحقول إن وُجدت.
class ValidationException extends AppException {
  const ValidationException({
    String message = 'البيانات المُدخلة غير صحيحة.',
    this.fieldErrors = const {},
    super.details,
    super.statusCode,
  }) : super(message);

  final Map<String, String> fieldErrors;
}

/// خطأ في الخادم (5xx).
class ServerException extends AppException {
  const ServerException({
    String message = 'حدث خطأ في الخادم. أعد المحاولة بعد قليل.',
    super.details,
    super.statusCode,
  }) : super(message);
}

/// خطأ في التخزين المحلي (قاعدة البيانات أو الملفات).
class CacheException extends AppException {
  const CacheException({
    String message = 'تعذّر الوصول إلى البيانات المخزّنة على الجهاز.',
    super.details,
  }) : super(message);
}

/// مساحة التخزين غير كافية لتحميل الدرس.
class StorageFullException extends AppException {
  const StorageFullException({
    String message = 'المساحة المتاحة على الجهاز غير كافية لتحميل هذا الدرس.',
    super.details,
  }) : super(message);
}

/// إعداد ناقص (مثلًا `BASE_URL` غير معرّف).
class ConfigException extends AppException {
  const ConfigException({
    String message = 'إعدادات التطبيق غير مكتملة.',
    super.details,
  }) : super(message);
}

/// المحتوى المطلوب غير محمَّل على الجهاز ولا يوجد اتصال.
class OfflineContentException extends AppException {
  const OfflineContentException({
    String message =
        'هذا المحتوى غير محمَّل على جهازك ويحتاج اتصالًا بالإنترنت.',
    super.details,
  }) : super(message);
}

/// خطأ غير متوقع.
class UnknownException extends AppException {
  const UnknownException({
    String message = 'حدث خطأ غير متوقع.',
    super.details,
  }) : super(message);
}
