import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../core/config/env.dart';
import '../../core/error/app_exception.dart';
import '../../core/error/error_mapper.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/lesson_block.dart';

/// نتيجة رفع فيديو من جهاز الأستاذ.
class UploadedVideo {
  const UploadedVideo({
    required this.url,
    this.thumbnailUrl,
    this.durationSeconds = 0,
    this.sizeBytes = 0,
  });

  final String url;
  final String? thumbnailUrl;
  final int durationSeconds;
  final int sizeBytes;

  factory UploadedVideo.fromJson(Map<String, dynamic> json) => UploadedVideo(
        url: (json['url'] ?? '') as String,
        thumbnailUrl: json['thumbnail_url'] as String?,
        durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
        sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      );
}

/// رفع ملفات الفيديو مع تقدّم الرفع وإمكانية الإلغاء.
class UploadApi {
  const UploadApi(this._client);

  final ApiClient _client;

  /// [onProgress] تُستدعى بنسبة من 0.0 إلى 1.0 (أو -1 إن كان الحجم مجهولًا).
  Future<UploadedVideo> uploadVideo({
    required File file,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (!file.existsSync()) {
      throw const ValidationException(message: 'الملف المختار غير موجود.');
    }

    final size = await file.length();
    if (size > Env.maxVideoUploadBytes) {
      throw ValidationException(
        message:
            'حجم الفيديو يتجاوز الحد المسموح (${Env.maxVideoUploadMb} م.ب).',
      );
    }

    // وضع التجربة: لا خادم يستقبل الملف، فنحاكي الرفع مع تقدّم حقيقي في
    // الواجهة ثم نُرجع رابط عيّنة عامة ليبقى الفيديو قابلًا للتشغيل.
    if (_client.isDemo) {
      return _simulateUpload(sizeBytes: size, onProgress: onProgress);
    }

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: p.basename(file.path),
      ),
    });

    try {
      final response = await _client.dio.post<dynamic>(
        ApiEndpoints.uploadVideo,
        data: formData,
        cancelToken: cancelToken,
        options: Options(
          sendTimeout: Env.uploadTimeout,
          receiveTimeout: Env.uploadTimeout,
        ),
        onSendProgress: (sent, total) {
          if (onProgress == null) return;
          onProgress(total <= 0 ? -1 : sent / total);
        },
      );

      final data = response.data;
      if (data is! Map) {
        throw const ServerException(message: 'رد الخادم بعد الرفع غير متوقّع.');
      }
      final map = Map<String, dynamic>.from(data);
      final inner = map['data'];
      return UploadedVideo.fromJson(
        inner is Map ? Map<String, dynamic>.from(inner) : map,
      );
    } on DioException catch (error) {
      throw ErrorMapper.fromDio(error);
    }
  }

  /// رفع مرفق PDF لفقرة فيديو.
  ///
  /// يتحقّق محليًا من الامتداد والحجم قبل بدء الرفع، فلا ننتظر رفض الخادم
  /// بعد إرسال ملف كبير.
  Future<BlockAttachment> uploadAttachment({
    required String blockId,
    required File file,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (!file.existsSync()) {
      throw const ValidationException(message: 'الملف المختار غير موجود.');
    }
    final name = p.basename(file.path);
    if (p.extension(name).toLowerCase() != '.pdf') {
      throw const ValidationException(message: 'الملف يجب أن يكون بصيغة PDF.');
    }

    final size = await file.length();
    if (size > Env.maxAttachmentBytes) {
      throw ValidationException(
        message: 'حجم الملف يتجاوز الحد المسموح '
            '(${Env.maxAttachmentMb} م.ب).',
      );
    }

    if (_client.isDemo) {
      const steps = 6;
      for (var step = 1; step <= steps; step++) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        onProgress?.call(step / steps);
      }
      return BlockAttachment(
        id: 'att-${DateTime.now().microsecondsSinceEpoch}',
        fileName: name,
        url: demoAttachmentUrl,
        sizeBytes: size,
        createdAt: DateTime.now().toUtc(),
      );
    }

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: name),
    });

    try {
      final response = await _client.dio.post<dynamic>(
        ApiEndpoints.blockAttachments(blockId),
        data: formData,
        cancelToken: cancelToken,
        options: Options(
          sendTimeout: Env.uploadTimeout,
          receiveTimeout: Env.uploadTimeout,
        ),
        onSendProgress: (sent, total) {
          if (onProgress == null) return;
          onProgress(total <= 0 ? -1 : sent / total);
        },
      );

      final data = response.data;
      if (data is! Map) {
        throw const ServerException(message: 'رد الخادم بعد الرفع غير متوقّع.');
      }
      final map = Map<String, dynamic>.from(data);
      final inner = map['data'];
      return BlockAttachment.fromJson(
        inner is Map ? Map<String, dynamic>.from(inner) : map,
      );
    } on DioException catch (error) {
      throw ErrorMapper.fromDio(error);
    }
  }

  /// حذف مرفق.
  Future<void> deleteAttachment(String attachmentId) =>
      _client.delete(ApiEndpoints.attachment(attachmentId));

  /// رفع وهمي في وضع التجربة: يتقدّم على عشر خطوات خلال ثانيتين تقريبًا.
  static Future<UploadedVideo> _simulateUpload({
    required int sizeBytes,
    void Function(double progress)? onProgress,
  }) async {
    const steps = 10;
    for (var step = 1; step <= steps; step++) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      onProgress?.call(step / steps);
    }
    return UploadedVideo(
      url: demoUploadedVideoUrl,
      durationSeconds: 15,
      sizeBytes: sizeBytes,
    );
  }
}

/// الرابط الذي يُرجعه الرفع الوهمي في وضع التجربة (عيّنة عامة).
const String demoUploadedVideoUrl =
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4';

/// ملف PDF عام صغير يُستعمل كمرفق في وضع التجربة.
const String demoAttachmentUrl =
    'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf';
