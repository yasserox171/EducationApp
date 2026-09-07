import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/error/app_exception.dart';
import '../../core/network/network_info.dart';
import '../../core/utils/logger.dart';
import '../../core/storage/dao/content_dao.dart';
import '../models/enums.dart';
import '../models/lesson.dart';
import '../models/lesson_block.dart';
import '../models/subject.dart';
import '../models/teacher_stats.dart';
import '../remote/content_api.dart';
import '../remote/stats_api.dart';
import '../remote/upload_api.dart';

/// عمليات الأستاذ. كلها تتطلّب اتصالًا: المحتوى يجب أن يصل الخادم فورًا حتى
/// لا يتفرّع مصدران للحقيقة. بعد كل عملية ناجحة تُحدَّث النسخة المحلية.
class TeacherRepository {
  TeacherRepository({
    required ContentApi contentApi,
    required UploadApi uploadApi,
    required StatsApi statsApi,
    required ContentDao dao,
    required NetworkInfo networkInfo,
    bool isDemo = false,
  })  : _contentApi = contentApi,
        _uploadApi = uploadApi,
        _statsApi = statsApi,
        _dao = dao,
        _networkInfo = networkInfo,
        _isDemo = isDemo;

  final ContentApi _contentApi;
  final UploadApi _uploadApi;
  final StatsApi _statsApi;
  final ContentDao _dao;
  final NetworkInfo _networkInfo;

  /// في وضع التجربة الخادم وهمي داخل التطبيق، فلا معنى لاشتراط الاتصال.
  final bool _isDemo;

  Future<void> _requireOnline() async {
    if (_isDemo) return;
    if (!await _networkInfo.isOnline) {
      throw const NetworkException(
        message: 'تعديل المحتوى يحتاج اتصالًا بالإنترنت.',
      );
    }
  }

  // ------------------------------------------------------------- المواد

  Future<Subject> createSubject({
    required String title,
    String? description,
  }) async {
    await _requireOnline();
    if (title.trim().isEmpty) {
      throw const ValidationException(message: 'اسم المادة مطلوب.');
    }
    final subject = await _contentApi.createSubject(
      title: title.trim(),
      description: description?.trim(),
    );
    await _dao.upsertSubject(subject);
    return subject;
  }

  Future<Subject> updateSubject({
    required String id,
    required String title,
    String? description,
  }) async {
    await _requireOnline();
    final subject = await _contentApi.updateSubject(
      id,
      title: title.trim(),
      description: description?.trim(),
    );
    await _dao.upsertSubject(subject);
    return subject;
  }

  Future<void> deleteSubject(String id) async {
    await _requireOnline();
    await _contentApi.deleteSubject(id);
    await _dao.deleteSubject(id);
  }

  // ------------------------------------------------------------- الدروس

  Future<Lesson> createLesson({
    required String subjectId,
    required String title,
    required LessonLevel level,
    String? summary,
  }) async {
    await _requireOnline();
    if (title.trim().isEmpty) {
      throw const ValidationException(message: 'عنوان الدرس مطلوب.');
    }
    final lesson = await _contentApi.createLesson(
      subjectId: subjectId,
      title: title.trim(),
      level: level,
      summary: summary?.trim(),
    );
    await _dao.upsertLesson(lesson);
    return lesson;
  }

  Future<Lesson> updateLesson({
    required String id,
    String? title,
    LessonLevel? level,
    String? summary,
    bool? isPublished,
  }) async {
    await _requireOnline();
    final lesson = await _contentApi.updateLesson(
      id,
      title: title?.trim(),
      level: level,
      summary: summary?.trim(),
      isPublished: isPublished,
    );
    await _dao.upsertLesson(lesson);
    return lesson;
  }

  Future<void> deleteLesson(String id) async {
    await _requireOnline();
    await _contentApi.deleteLesson(id);
    await _dao.deleteLesson(id);
  }

  /// إعادة ترتيب الدروس: نطبّق الترتيب محليًا أولًا ليكون السحب والإفلات
  /// فوريًا، ثم نرسله. عند الفشل نعيد الترتيب السابق.
  Future<void> reorderLessons({
    required String subjectId,
    required List<String> orderedIds,
  }) async {
    await _requireOnline();
    final previous = await _dao.getLessons(subjectId: subjectId);
    await _dao.applyLessonOrder(orderedIds);
    try {
      await _contentApi.reorderLessons(
        subjectId: subjectId,
        orderedIds: orderedIds,
      );
    } on AppException {
      await _dao.applyLessonOrder(
        previous.map((lesson) => lesson.id).toList(growable: false),
      );
      rethrow;
    }
  }

  // ------------------------------------------------------------ الفقرات

  Future<List<LessonBlock>> getBlocksForEditing(String lessonId) async {
    await _requireOnline();
    final blocks = await _contentApi.fetchBlocks(lessonId);
    await _dao.replaceBlocks(lessonId, blocks);
    return blocks;
  }

  Future<LessonBlock> addTextBlock({
    required String lessonId,
    String? heading,
    required String body,
  }) async {
    await _requireOnline();
    if (body.trim().isEmpty) {
      throw const ValidationException(message: 'نص الفقرة مطلوب.');
    }
    return _contentApi.createBlock(
      lessonId: lessonId,
      type: BlockType.text,
      data: {'heading': heading?.trim(), 'body': body.trim()},
    );
  }

  /// رفع فيديو ثم إنشاء فقرة تشير إليه.
  /// [onProgress] لشريط تقدم الرفع (0.0 → 1.0).
  Future<LessonBlock> addVideoBlock({
    required String lessonId,
    required File file,
    String? title,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    await _requireOnline();
    final uploaded = await _uploadApi.uploadVideo(
      file: file,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    return _contentApi.createBlock(
      lessonId: lessonId,
      type: BlockType.video,
      data: {
        'title': title?.trim(),
        'url': uploaded.url,
        'thumbnail_url': uploaded.thumbnailUrl,
        'duration_seconds': uploaded.durationSeconds,
        'size_bytes': uploaded.sizeBytes,
      },
    );
  }

  Future<LessonBlock> addQuizBlock({
    required String lessonId,
    required List<QuizQuestion> questions,
  }) async {
    await _requireOnline();
    _validateQuiz(questions);
    return _contentApi.createBlock(
      lessonId: lessonId,
      type: BlockType.quiz,
      data: quizDataOf(questions),
    );
  }

  /// شكل بيانات فقرة الكويز المتفق عليه مع الخادم.
  static Map<String, dynamic> quizDataOf(List<QuizQuestion> questions) => {
        'questions': questions.map((e) => e.toJson()).toList(growable: false),
      };

  /// إرفاق ملف PDF بفقرة فيديو: يُرفع الملف ثم يُضاف إلى بيانات الفقرة.
  Future<LessonBlock> attachPdf({
    required VideoBlock block,
    required File file,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    await _requireOnline();
    final uploaded = await _uploadApi.uploadAttachment(
      blockId: block.id,
      file: file,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );

    final attachments = [...block.attachments, uploaded];
    return _contentApi.updateBlock(
      blockId: block.id,
      data: _videoDataOf(block, attachments),
    );
  }

  /// إزالة مرفق من فقرة فيديو.
  Future<LessonBlock> removeAttachment({
    required VideoBlock block,
    required String attachmentId,
  }) async {
    await _requireOnline();
    final attachments = block.attachments
        .where((attachment) => attachment.id != attachmentId)
        .toList(growable: false);

    final updated = await _contentApi.updateBlock(
      blockId: block.id,
      data: _videoDataOf(block, attachments),
    );
    try {
      await _uploadApi.deleteAttachment(attachmentId);
    } on AppException catch (error) {
      // الفقرة تحدّثت فعلًا؛ فشل حذف الملف من التخزين ليس سببًا لإفشال
      // العملية أمام الأستاذ.
      Log.d('TeacherRepository', 'تعذّر حذف المرفق: ${error.message}');
    }
    return updated;
  }

  static Map<String, dynamic> _videoDataOf(
    VideoBlock block,
    List<BlockAttachment> attachments,
  ) =>
      {
        'title': block.title,
        'url': block.remoteUrl,
        'thumbnail_url': block.thumbnailUrl,
        'duration_seconds': block.durationSeconds,
        'size_bytes': block.sizeBytes,
        'attachments':
            attachments.map((e) => e.toJson()).toList(growable: false),
      };

  Future<LessonBlock> updateBlock({
    required String blockId,
    required Map<String, dynamic> data,
  }) async {
    await _requireOnline();
    return _contentApi.updateBlock(blockId: blockId, data: data);
  }

  Future<void> deleteBlock(String blockId) async {
    await _requireOnline();
    await _contentApi.deleteBlock(blockId);
  }

  Future<void> reorderBlocks({
    required String lessonId,
    required List<String> orderedIds,
  }) async {
    await _requireOnline();
    await _contentApi.reorderBlocks(
      lessonId: lessonId,
      orderedIds: orderedIds,
    );
  }

  static void _validateQuiz(List<QuizQuestion> questions) {
    if (questions.isEmpty) {
      throw const ValidationException(message: 'أضف سؤالًا واحدًا على الأقل.');
    }
    for (final question in questions) {
      if (question.question.trim().isEmpty) {
        throw const ValidationException(message: 'نص السؤال مطلوب.');
      }
      if (question.options.length < 2) {
        throw const ValidationException(message: 'أضف خيارين على الأقل.');
      }
      if (question.options.any((option) => option.text.trim().isEmpty)) {
        throw const ValidationException(message: 'لا يمكن ترك خيار فارغًا.');
      }
      if (!question.options
          .any((option) => option.id == question.correctOptionId)) {
        throw const ValidationException(
          message: 'حدّد الإجابة الصحيحة لكل سؤال.',
        );
      }
    }
  }

  // --------------------------------------------------------- الإحصائيات

  Future<TeacherStats> fetchStats() async {
    await _requireOnline();
    return _statsApi.fetchTeacherStats();
  }
}
