import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../error/app_exception.dart';

/// إدارة ملفات الوسائط المحمَّلة على الجهاز.
///
/// البنية: `<ApplicationSupportDirectory>/lessons/<lessonId>/<blockId>.<ext>`
/// اخترنا مجلد الدعم (لا مجلد المستندات) حتى لا تظهر الملفات للمستخدم في
/// تطبيقات الملفات، ولا تُرفع تلقائيًا إلى iCloud.
class MediaStore {
  MediaStore({Directory? rootOverride}) : _rootOverride = rootOverride;

  final Directory? _rootOverride;
  Directory? _cachedRoot;

  Future<Directory> _root() async {
    if (_rootOverride != null) return _rootOverride;
    final cached = _cachedRoot;
    if (cached != null) return cached;
    final base = await getApplicationSupportDirectory();
    final root = Directory(p.join(base.path, 'lessons'));
    if (!root.existsSync()) {
      await root.create(recursive: true);
    }
    _cachedRoot = root;
    return root;
  }

  Future<Directory> lessonDirectory(String lessonId) async {
    final root = await _root();
    final dir = Directory(p.join(root.path, lessonId));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// مسار الملف النهائي لفقرة فيديو.
  Future<String> filePathFor({
    required String lessonId,
    required String blockId,
    required String remoteUrl,
  }) async {
    final dir = await lessonDirectory(lessonId);
    return p.join(dir.path, '$blockId${_extensionOf(remoteUrl)}');
  }

  /// مسار مؤقّت أثناء التحميل — يُعاد تسميته عند الاكتمال حتى لا يُعتبر
  /// ملف نصف محمَّل ملفًا صالحًا.
  String partialPathFor(String finalPath) => '$finalPath.part';

  static String _extensionOf(String url) {
    final uri = Uri.tryParse(url);
    final ext = p.extension(uri?.path ?? url);
    if (ext.isEmpty || ext.length > 6) return '.mp4';
    return ext;
  }

  Future<bool> exists(String path) => File(path).exists();

  Future<int> fileSize(String path) async {
    final file = File(path);
    if (!file.existsSync()) return 0;
    return file.length();
  }

  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  /// حذف كل ملفات درس (زر «حذف التحميل»).
  Future<void> deleteLesson(String lessonId) async {
    final root = await _root();
    final dir = Directory(p.join(root.path, lessonId));
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }

  /// حذف كل الملفات المحمَّلة (تسجيل الخروج، أو «تحرير المساحة»).
  Future<void> clearAll() async {
    final root = await _root();
    if (root.existsSync()) {
      await root.delete(recursive: true);
    }
    _cachedRoot = null;
  }

  /// الحجم الإجمالي للملفات المحمَّلة على الجهاز (بالبايت).
  Future<int> totalBytes() async {
    final root = await _root();
    if (!root.existsSync()) return 0;
    var total = 0;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  Future<int> lessonBytes(String lessonId) async {
    final root = await _root();
    final dir = Directory(p.join(root.path, lessonId));
    if (!dir.existsSync()) return 0;
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  /// يتحقّق من وجود مساحة كافية قبل بدء تحميل درس.
  Future<void> ensureSpaceFor(int requiredBytes, {required int quotaBytes}) async {
    final used = await totalBytes();
    if (used + requiredBytes > quotaBytes) {
      throw StorageFullException(
        details: 'used=$used required=$requiredBytes quota=$quotaBytes',
      );
    }
  }
}
