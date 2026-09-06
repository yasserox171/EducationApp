import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/enums.dart';
import '../models/lesson.dart';
import '../models/lesson_block.dart';
import '../models/subject.dart';

/// قراءة المحتوى (للطرفين) + عمليات الكتابة الخاصة بالأستاذ.
class ContentApi {
  const ContentApi(this._client);

  final ApiClient _client;

  // ------------------------------------------------------------ قراءة

  Future<List<Subject>> fetchSubjects() async {
    final list = await _client.getList(ApiEndpoints.subjects);
    return list.map(Subject.fromJson).toList(growable: false);
  }

  Future<List<Lesson>> fetchLessons(
    String subjectId, {
    LessonLevel? level,
  }) async {
    final list = await _client.getList(
      ApiEndpoints.subjectLessons(subjectId),
      query: level == null ? null : {'level': level.wire},
    );
    return list.map(Lesson.fromJson).toList(growable: false);
  }

  Future<List<LessonBlock>> fetchBlocks(String lessonId) async {
    final list = await _client.getList(ApiEndpoints.lessonBlocks(lessonId));
    return list.map(LessonBlock.fromJson).toList(growable: false);
  }

  // -------------------------------------------------- كتابة (الأستاذ فقط)

  Future<Subject> createSubject({
    required String title,
    String? description,
  }) async {
    final json = await _client.post(
      ApiEndpoints.subjects,
      body: {'title': title, 'description': description},
    );
    return Subject.fromJson(json);
  }

  Future<Subject> updateSubject(
    String id, {
    required String title,
    String? description,
  }) async {
    final json = await _client.put(
      ApiEndpoints.subject(id),
      body: {'title': title, 'description': description},
    );
    return Subject.fromJson(json);
  }

  Future<void> deleteSubject(String id) =>
      _client.delete(ApiEndpoints.subject(id));

  Future<Lesson> createLesson({
    required String subjectId,
    required String title,
    required LessonLevel level,
    String? summary,
  }) async {
    final json = await _client.post(
      ApiEndpoints.lessons,
      body: {
        'subject_id': subjectId,
        'title': title,
        'level': level.wire,
        'summary': summary,
      },
    );
    return Lesson.fromJson(json);
  }

  Future<Lesson> updateLesson(
    String id, {
    String? title,
    LessonLevel? level,
    String? summary,
    bool? isPublished,
  }) async {
    final json = await _client.put(
      ApiEndpoints.lesson(id),
      body: {
        if (title != null) 'title': title,
        if (level != null) 'level': level.wire,
        if (summary != null) 'summary': summary,
        if (isPublished != null) 'is_published': isPublished,
      },
    );
    return Lesson.fromJson(json);
  }

  Future<void> deleteLesson(String id) => _client.delete(ApiEndpoints.lesson(id));

  Future<void> reorderLessons({
    required String subjectId,
    required List<String> orderedIds,
  }) =>
      _client.post(
        ApiEndpoints.subjectLessonsReorder(subjectId),
        body: {'lesson_ids': orderedIds},
      );

  /// إنشاء فقرة. `data` هو الجزء الخاص بالنوع (نص/فيديو/كويز).
  Future<LessonBlock> createBlock({
    required String lessonId,
    required BlockType type,
    required Map<String, dynamic> data,
    int? position,
  }) async {
    final json = await _client.post(
      ApiEndpoints.lessonBlocks(lessonId),
      body: {
        'type': type.wire,
        'data': data,
        if (position != null) 'position': position,
      },
    );
    return LessonBlock.fromJson(json);
  }

  Future<LessonBlock> updateBlock({
    required String blockId,
    required Map<String, dynamic> data,
  }) async {
    final json = await _client.put(
      ApiEndpoints.block(blockId),
      body: {'data': data},
    );
    return LessonBlock.fromJson(json);
  }

  Future<void> deleteBlock(String blockId) =>
      _client.delete(ApiEndpoints.block(blockId));

  Future<void> reorderBlocks({
    required String lessonId,
    required List<String> orderedIds,
  }) =>
      _client.post(
        ApiEndpoints.lessonBlocksReorder(lessonId),
        body: {'block_ids': orderedIds},
      );
}
