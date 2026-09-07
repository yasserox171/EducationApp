import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// إعدادات التطبيق القادمة من ملف `.env` أو من `--dart-define`.
///
/// لا يوجد أي عنوان خادم مكتوب داخل الكود: القيمة تُقرأ أولًا من `.env`
/// (المرفق كأصل asset) وإن لم توجد تُقرأ من `--dart-define=BASE_URL=...`
/// المستعمل عادة في سلاسل البناء (CI).
class Env {
  const Env._();

  static const String _envFileName = '.env';
  static bool _dotenvLoaded = false;

  /// تُستدعى مرة واحدة في `main()` قبل `runApp`.
  /// لا ترمي استثناءً إن كان الملف غير موجود — التطبيق يعرض شاشة إعداد بدلًا
  /// من الانهيار.
  static Future<void> load() async {
    try {
      await dotenv.load(fileName: _envFileName);
      _dotenvLoaded = true;
    } catch (_) {
      _dotenvLoaded = false;
    }
  }

  static const String _baseUrlFromDefine = String.fromEnvironment('BASE_URL');

  /// قيم بديلة تُستعمل في الاختبارات فقط بدل قراءة ملف `.env`.
  static Map<String, String>? _testValues;

  @visibleForTesting
  static void setTestValues(Map<String, String>? values) =>
      _testValues = values;

  static String _read(String key, {String fallback = ''}) {
    final overrides = _testValues;
    if (overrides != null) {
      final value = overrides[key];
      return value != null && value.trim().isNotEmpty
          ? value.trim()
          : fallback;
    }
    if (_dotenvLoaded) {
      final value = dotenv.env[key];
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return fallback;
  }

  static int _readInt(String key, int fallback) =>
      int.tryParse(_read(key)) ?? fallback;

  static bool _readBool(String key, {bool fallback = false}) {
    final raw = _read(key).toLowerCase();
    if (raw.isEmpty) return fallback;
    return raw == 'true' || raw == '1' || raw == 'yes';
  }

  /// عنوان الـ API الأساسي، بدون `/` في النهاية.
  static String get baseUrl {
    final raw = _read('BASE_URL', fallback: _baseUrlFromDefine);
    if (raw.endsWith('/')) return raw.substring(0, raw.length - 1);
    return raw;
  }

  /// وضع التجربة: التطبيق يعمل بخادم وهمي في الذاكرة، بلا أي اتصال بخادم
  /// حقيقي. يُفعّل بـ `DEMO_MODE=true` في `.env`.
  static bool get demoMode => _readBool('DEMO_MODE');

  /// هل التطبيق مُهيّأ للاتصال بالخادم؟
  /// إن كانت `false` يعرض التطبيق شاشة «الإعداد ناقص» بدل شاشة الدخول.
  /// في وضع التجربة لا حاجة لعنوان خادم أصلًا.
  static bool get isConfigured {
    if (demoMode) return true;
    final url = baseUrl;
    return url.isNotEmpty &&
        (url.startsWith('http://') || url.startsWith('https://'));
  }

  static Duration get connectTimeout =>
      Duration(seconds: _readInt('CONNECT_TIMEOUT_SECONDS', 20));

  static Duration get receiveTimeout =>
      Duration(seconds: _readInt('RECEIVE_TIMEOUT_SECONDS', 60));

  static Duration get uploadTimeout =>
      Duration(minutes: _readInt('UPLOAD_TIMEOUT_MINUTES', 30));

  /// الحد الأقصى لحجم فيديو يرفعه الأستاذ (بالبايت).
  static int get maxVideoUploadBytes =>
      _readInt('MAX_VIDEO_UPLOAD_MB', 300) * 1024 * 1024;

  static int get maxVideoUploadMb => _readInt('MAX_VIDEO_UPLOAD_MB', 300);

  /// الحد الأقصى لحجم مرفق PDF (بالبايت).
  static int get maxAttachmentBytes =>
      _readInt('MAX_ATTACHMENT_MB', 20) * 1024 * 1024;

  static int get maxAttachmentMb => _readInt('MAX_ATTACHMENT_MB', 20);

  /// الحد الأقصى الإجمالي للملفات المحمّلة على الجهاز (بالبايت).
  static int get maxOfflineStorageBytes =>
      _readInt('MAX_OFFLINE_STORAGE_MB', 4096) * 1024 * 1024;

  static bool get verboseHttpLogs => _readBool('VERBOSE_HTTP_LOGS');
}
