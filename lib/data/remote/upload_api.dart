import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../core/config/env.dart';
import '../../core/error/app_exception.dart';
import '../../core/error/error_mapper.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';

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
}
