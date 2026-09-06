import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/config/env.dart';
import '../../core/error/app_exception.dart';
import '../../core/error/error_mapper.dart';
import '../../core/network/network_info.dart';
import '../../core/storage/dao/download_dao.dart';
import '../../core/storage/media_store.dart';
import '../../core/utils/logger.dart';
import '../models/download_state.dart';
import '../models/enums.dart';
import '../models/lesson_block.dart';
import 'content_repository.dart';

/// تحميل الدروس على الجهاز — يدوي بالكامل (زر «تحميل» في الدرس).
///
/// خطوات تحميل درس:
/// 1. سحب فقرات الدرس وتخزينها محليًا (النصوص والكويزات تصبح متاحة فورًا).
/// 2. حساب الحجم الإجمالي للفيديوهات والتأكد من وجود مساحة كافية.
/// 3. تحميل كل فيديو إلى ملف `.part` ثم إعادة تسميته عند الاكتمال
///    (حتى لا يُعتبر ملف نصف محمَّل جاهزًا للتشغيل).
class DownloadRepository {
  DownloadRepository({
    required ContentRepository contentRepository,
    required DownloadDao dao,
    required MediaStore mediaStore,
    required NetworkInfo networkInfo,
    required Dio dio,
  })  : _content = contentRepository,
        _dao = dao,
        _mediaStore = mediaStore,
        _networkInfo = networkInfo,
        _dio = dio;

  final ContentRepository _content;
  final DownloadDao _dao;
  final MediaStore _mediaStore;
  final NetworkInfo _networkInfo;
  final Dio _dio;

  final Map<String, StreamController<LessonDownload>> _controllers = {};
  final Map<String, CancelToken> _cancelTokens = {};

  /// تدفّق حالة تحميل درس معيّن (لعرض شريط التقدم).
  Stream<LessonDownload> watch(String lessonId) =>
      _controllerFor(lessonId).stream;

  StreamController<LessonDownload> _controllerFor(String lessonId) =>
      _controllers.putIfAbsent(
        lessonId,
        () => StreamController<LessonDownload>.broadcast(),
      );

  Future<LessonDownload> status(String lessonId) async =>
      await _dao.getLessonDownload(lessonId) ?? LessonDownload.none(lessonId);

  Future<Map<String, LessonDownload>> statuses(List<String> lessonIds) =>
      _dao.getLessonDownloads(lessonIds);

  bool isDownloading(String lessonId) => _cancelTokens.containsKey(lessonId);

  /// المسار المحلي لفيديو فقرة، أو `null` إن لم يكن محمَّلًا.
  Future<String?> localPathFor(String blockId) async {
    final media = await _dao.getMediaFile(blockId);
    if (media == null || !media.isReady) return null;
    final path = media.localPath!;
    if (!await _mediaStore.exists(path)) {
      // الملف حُذف من خارج التطبيق — نصحّح السجل.
      await _dao.upsertMediaFile(
        MediaFile(
          blockId: media.blockId,
          lessonId: media.lessonId,
          remoteUrl: media.remoteUrl,
          status: DownloadStatus.none,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      return null;
    }
    return path;
  }

  // ------------------------------------------------------------- التحميل

  Future<void> downloadLesson(String lessonId) async {
    if (isDownloading(lessonId)) return;

    if (!await _networkInfo.isOnline) {
      throw const NetworkException(
        message: 'التحميل يحتاج اتصالًا بالإنترنت.',
      );
    }

    final cancelToken = CancelToken();
    _cancelTokens[lessonId] = cancelToken;

    var state = LessonDownload(
      lessonId: lessonId,
      status: DownloadStatus.queued,
      updatedAt: DateTime.now().toUtc(),
    );
    await _emit(state);

    try {
      // 1) الفقرات أولًا: بها يصبح الدرس قابلًا للفتح بدون إنترنت.
      final blocks = await _content.getBlocks(lessonId, forceRefresh: true);
      final videos = blocks.whereType<VideoBlock>().toList(growable: false);

      if (videos.isEmpty) {
        state = state.copyWith(
          status: DownloadStatus.completed,
          completedAt: DateTime.now().toUtc(),
        );
        await _emit(state);
        return;
      }

      // 2) الحجم المتوقّع (قد يكون 0 إن لم يرسله الخادم).
      final expectedBytes =
          videos.fold<int>(0, (sum, video) => sum + video.sizeBytes);
      if (expectedBytes > 0) {
        await _mediaStore.ensureSpaceFor(
          expectedBytes,
          quotaBytes: Env.maxOfflineStorageBytes,
        );
      }

      state = state.copyWith(
        status: DownloadStatus.downloading,
        totalBytes: expectedBytes,
        downloadedBytes: 0,
      );
      await _emit(state);

      // 3) تحميل الملفات واحدًا تلو الآخر.
      var completedBytes = 0;
      for (final video in videos) {
        final path = await _downloadVideo(
          video: video,
          cancelToken: cancelToken,
          onBytes: (received, total) {
            final liveTotal = expectedBytes > 0
                ? expectedBytes
                : completedBytes + (total > 0 ? total : received);
            state = state.copyWith(
              downloadedBytes: completedBytes + received,
              totalBytes: liveTotal,
            );
            _emitSync(state);
          },
        );
        completedBytes += await _mediaStore.fileSize(path);
      }

      state = state.copyWith(
        status: DownloadStatus.completed,
        downloadedBytes: completedBytes,
        totalBytes: completedBytes,
        completedAt: DateTime.now().toUtc(),
      );
      await _emit(state);
    } on AppException catch (error) {
      await _emit(
        state.copyWith(status: DownloadStatus.failed, error: error.message),
      );
      rethrow;
    } catch (error, stackTrace) {
      final mapped = ErrorMapper.fromAny(error, stackTrace);
      await _emit(
        state.copyWith(status: DownloadStatus.failed, error: mapped.message),
      );
      throw mapped;
    } finally {
      _cancelTokens.remove(lessonId);
    }
  }

  Future<String> _downloadVideo({
    required VideoBlock video,
    required CancelToken cancelToken,
    required void Function(int received, int total) onBytes,
  }) async {
    final finalPath = await _mediaStore.filePathFor(
      lessonId: video.lessonId,
      blockId: video.id,
      remoteUrl: video.remoteUrl,
    );

    // موجود مسبقًا وسليم → لا نعيد التحميل.
    if (await _mediaStore.exists(finalPath)) {
      final size = await _mediaStore.fileSize(finalPath);
      if (size > 0) {
        await _dao.upsertMediaFile(
          MediaFile(
            blockId: video.id,
            lessonId: video.lessonId,
            remoteUrl: video.remoteUrl,
            localPath: finalPath,
            bytesTotal: size,
            bytesDownloaded: size,
            status: DownloadStatus.completed,
            updatedAt: DateTime.now().toUtc(),
          ),
        );
        onBytes(size, size);
        return finalPath;
      }
    }

    final partialPath = _mediaStore.partialPathFor(finalPath);
    final partialFile = File(partialPath);
    final alreadyHave =
        partialFile.existsSync() ? await partialFile.length() : 0;

    await _dao.upsertMediaFile(
      MediaFile(
        blockId: video.id,
        lessonId: video.lessonId,
        remoteUrl: video.remoteUrl,
        bytesTotal: video.sizeBytes,
        bytesDownloaded: alreadyHave,
        status: DownloadStatus.downloading,
        updatedAt: DateTime.now().toUtc(),
      ),
    );

    try {
      // نكتب التدفّق يدويًا (لا `dio.download`) لأن `download` يستبدل الملف
      // من أوله، وهو ما يُفسد الاستئناف: مع ترويسة Range سيكتب الجزء
      // الجديد فوق البداية. هنا نفتح الملف في وضع الإضافة عند 206.
      final response = await _dio.get<ResponseBody>(
        video.remoteUrl,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: alreadyHave > 0 ? {'Range': 'bytes=$alreadyHave-'} : null,
          receiveTimeout: Env.uploadTimeout,
          followRedirects: true,
          validateStatus: (status) =>
              status != null && (status == 200 || status == 206),
        ),
      );

      // 206 = الخادم قبِل الاستئناف. 200 = تجاهله ويرسل الملف كاملًا.
      final isResumed = response.statusCode == 206 && alreadyHave > 0;
      final totalBytes = _totalBytesOf(response, fallback: video.sizeBytes);

      final sink = partialFile.openWrite(
        mode: isResumed ? FileMode.append : FileMode.write,
      );
      var received = isResumed ? alreadyHave : 0;

      try {
        await for (final chunk in response.data!.stream) {
          sink.add(chunk);
          received += chunk.length;
          onBytes(received, totalBytes);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
    } on DioException catch (error) {
      final mapped = ErrorMapper.fromDio(error);
      await _dao.upsertMediaFile(
        MediaFile(
          blockId: video.id,
          lessonId: video.lessonId,
          remoteUrl: video.remoteUrl,
          status: DownloadStatus.failed,
          bytesDownloaded:
              partialFile.existsSync() ? await partialFile.length() : 0,
          error: mapped.message,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      throw mapped;
    }

    await partialFile.rename(finalPath);
    final size = await _mediaStore.fileSize(finalPath);

    await _dao.upsertMediaFile(
      MediaFile(
        blockId: video.id,
        lessonId: video.lessonId,
        remoteUrl: video.remoteUrl,
        localPath: finalPath,
        bytesTotal: size,
        bytesDownloaded: size,
        status: DownloadStatus.completed,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    return finalPath;
  }

  /// الحجم الكلّي للملف: من `Content-Range` عند الاستئناف، وإلا
  /// `Content-Length`، وإلا الحجم الذي أعلنه الخادم في بيانات الفقرة.
  static int _totalBytesOf(Response<ResponseBody> response, {int fallback = 0}) {
    final contentRange = response.headers.value('content-range');
    if (contentRange != null) {
      final total = contentRange.split('/').last.trim();
      final parsed = int.tryParse(total);
      if (parsed != null && parsed > 0) return parsed;
    }
    final contentLength = int.tryParse(
      response.headers.value('content-length') ?? '',
    );
    if (contentLength != null && contentLength > 0) return contentLength;
    return fallback;
  }

  /// إلغاء تحميل جارٍ. الملفات الجزئية تبقى ليُستأنف منها لاحقًا.
  Future<void> cancel(String lessonId) async {
    final token = _cancelTokens.remove(lessonId);
    token?.cancel('cancelled_by_user');
    final current = await status(lessonId);
    await _emit(
      current.copyWith(
        status: DownloadStatus.failed,
        error: 'تم إلغاء التحميل.',
      ),
    );
  }

  /// حذف ملفات درس محمَّل لتوفير المساحة.
  /// الفقرات النصية تبقى مخزَّنة (حجمها لا يُذكر) ليبقى الدرس قابلًا للقراءة.
  Future<void> deleteDownload(String lessonId) async {
    await cancelIfRunning(lessonId);
    try {
      await _mediaStore.deleteLesson(lessonId);
    } catch (error) {
      Log.d('DownloadRepository', 'تعذّر حذف ملفات $lessonId: $error');
    }
    await _dao.deleteLessonDownload(lessonId);
    await _emit(LessonDownload.none(lessonId));
  }

  Future<void> cancelIfRunning(String lessonId) async {
    if (isDownloading(lessonId)) {
      _cancelTokens.remove(lessonId)?.cancel('replaced');
    }
  }

  /// إجمالي المساحة المستعملة على الجهاز.
  Future<int> usedBytes() => _mediaStore.totalBytes();

  Future<void> deleteAllDownloads() async {
    for (final lessonId in _cancelTokens.keys.toList()) {
      _cancelTokens.remove(lessonId)?.cancel('wipe');
    }
    await _mediaStore.clearAll();
    for (final download in await _dao.getCompletedDownloads()) {
      await _dao.deleteLessonDownload(download.lessonId);
      await _emit(LessonDownload.none(download.lessonId));
    }
  }

  /// عند الإقلاع: تنظيف الحالات العالقة من جلسة سابقة.
  Future<void> reconcileOnStartup() => _dao.resetStaleDownloads();

  Future<void> _emit(LessonDownload state) async {
    await _dao.upsertLessonDownload(state);
    _emitSync(state);
  }

  void _emitSync(LessonDownload state) {
    final controller = _controllers[state.lessonId];
    if (controller != null && !controller.isClosed) {
      controller.add(state);
    }
  }

  void dispose() {
    for (final token in _cancelTokens.values) {
      token.cancel('disposed');
    }
    _cancelTokens.clear();
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
  }
}
