import 'package:dio/dio.dart';

import '../../core/error/app_exception.dart';
import '../../core/network/api_client.dart';
import 'demo_data.dart';

/// خادم وهمي في الذاكرة يُستعمل في وضع التجربة (`DEMO_MODE=true`).
///
/// يرث [ApiClient] ويعيد تعريف كل دوال الطلب، فيعمل التطبيق كاملًا —
/// الفضاءان معًا — دون أي خادم حقيقي ودون تعديل أي مستودع أو شاشة.
///
/// حدود الديمو (موثّقة في `docs/DEMO.md`):
/// * تعديلات الأستاذ تبقى في ذاكرة التطبيق: تعود البيانات إلى حالتها
///   الأصلية عند إعادة تشغيل التطبيق.
/// * تقدّم التلميذ وإجاباته تُخزَّن في قاعدة البيانات المحلية فتبقى محفوظة.
/// * رفع فيديو جديد محاكاة فقط (لا يوجد خادم يستقبله).
class DemoApiClient extends ApiClient {
  DemoApiClient() : super(dio: Dio());

  @override
  bool get isDemo => true;

  // --------------------------------------------------------------- الحالة
  final List<Map<String, dynamic>> _subjects = demoSubjects();
  final List<Map<String, dynamic>> _lessons = demoLessons();
  final Map<String, List<Map<String, dynamic>>> _blocks = demoBlocks();

  /// ما يدفعه التطبيق من تقدّم وإجابات ومستويات (يبقى داخل الجلسة).
  final Map<String, Map<String, dynamic>> _progress = {};
  final Map<String, Map<String, dynamic>> _levels = {};
  final List<Map<String, dynamic>> _attempts = [];

  Map<String, dynamic>? _currentUser;
  int _idCounter = 0;

  String _nextId(String prefix) => '$prefix-${++_idCounter}';

  String _now() => DateTime.now().toUtc().toIso8601String();

  /// تأخير بسيط حتى تظهر مؤشّرات التحميل في الواجهة كما مع خادم حقيقي.
  Future<void> _latency() =>
      Future<void>.delayed(const Duration(milliseconds: 220));

  // ------------------------------------------------------------- التوجيه

  @override
  Future<Map<String, dynamic>> getObject(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    await _latency();
    final segments = _segments(path);

    if (_matches(segments, ['auth', 'me'])) {
      final user = _currentUser;
      if (user == null) throw const UnauthorizedException();
      return Map<String, dynamic>.from(user);
    }
    if (_matches(segments, ['teacher', 'stats'])) {
      return _stats();
    }
    throw NotFoundException(details: 'GET $path');
  }

  @override
  Future<List<Map<String, dynamic>>> getList(
    String path, {
    Map<String, dynamic>? query,
    String dataKey = 'data',
  }) async {
    await _latency();
    final segments = _segments(path);

    if (_matches(segments, ['subjects'])) {
      return _subjects
          .map(
            (subject) => {
              ...subject,
              'lessons_count': _lessons
                  .where((lesson) => lesson['subject_id'] == subject['id'])
                  .length,
            },
          )
          .toList();
    }

    // /subjects/{id}/lessons
    if (segments.length == 3 &&
        segments[0] == 'subjects' &&
        segments[2] == 'lessons') {
      final subjectId = segments[1];
      final level = query?['level'] as String?;
      final lessons = _lessons
          .where((lesson) => lesson['subject_id'] == subjectId)
          .where((lesson) => level == null || lesson['level'] == level)
          .toList()
        ..sort(_byPosition);
      return lessons.map(Map<String, dynamic>.from).toList();
    }

    // /lessons/{id}/blocks
    if (segments.length == 3 &&
        segments[0] == 'lessons' &&
        segments[2] == 'blocks') {
      final blocks = [...?_blocks[segments[1]]]..sort(_byPosition);
      return blocks.map(Map<String, dynamic>.from).toList();
    }

    if (_matches(segments, ['me', 'progress'])) {
      return _progress.values.map(Map<String, dynamic>.from).toList();
    }
    if (_matches(segments, ['me', 'levels'])) {
      return _levels.values.map(Map<String, dynamic>.from).toList();
    }

    throw NotFoundException(details: 'GET $path');
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    await _latency();
    final segments = _segments(path);
    final data = _asMap(body);

    // ---------------------------------------------------------- المصادقة
    if (_matches(segments, ['auth', 'login'])) {
      return _login(data);
    }
    if (_matches(segments, ['auth', 'logout'])) {
      _currentUser = null;
      return const {};
    }

    // ------------------------------------------------------------ المواد
    if (_matches(segments, ['subjects'])) {
      final subject = <String, dynamic>{
        'id': _nextId('s'),
        'title': data['title'],
        'description': data['description'],
        'position': _subjects.length,
        'lessons_count': 0,
        'updated_at': _now(),
      };
      _subjects.add(subject);
      return Map<String, dynamic>.from(subject);
    }

    // ------------------------------------------------------------ الدروس
    if (_matches(segments, ['lessons'])) {
      final subjectId = data['subject_id'].toString();
      final lesson = <String, dynamic>{
        'id': _nextId('l'),
        'subject_id': subjectId,
        'title': data['title'],
        'summary': data['summary'],
        'level': data['level'] ?? 'middle',
        'position': _lessons
            .where((item) => item['subject_id'] == subjectId)
            .length,
        'blocks_count': 0,
        'is_published': true,
        'updated_at': _now(),
      };
      _lessons.add(lesson);
      _blocks[lesson['id']! as String] = [];
      return Map<String, dynamic>.from(lesson);
    }

    // /subjects/{id}/lessons/reorder
    if (segments.length == 4 &&
        segments[0] == 'subjects' &&
        segments[3] == 'reorder') {
      _applyOrder(
        ids: _stringList(data['lesson_ids']),
        items: _lessons,
      );
      return const {};
    }

    // /lessons/{id}/blocks  و  /lessons/{id}/blocks/reorder
    if (segments.length >= 3 &&
        segments[0] == 'lessons' &&
        segments[2] == 'blocks') {
      final lessonId = segments[1];
      if (segments.length == 4 && segments[3] == 'reorder') {
        _applyOrder(
          ids: _stringList(data['block_ids']),
          items: _blocks[lessonId] ?? [],
        );
        return const {};
      }

      final blocks = _blocks.putIfAbsent(lessonId, () => []);
      final block = <String, dynamic>{
        'id': _nextId('b'),
        'lesson_id': lessonId,
        'position': data['position'] ?? blocks.length,
        'type': data['type'],
        'data': _asMap(data['data']),
        'updated_at': _now(),
      };
      blocks.add(block);
      _syncBlocksCount(lessonId);
      return Map<String, dynamic>.from(block);
    }

    // ------------------------------------------------------- تقدّم التلميذ
    if (_matches(segments, ['me', 'progress', 'sync'])) {
      final lessonId = data['lesson_id']?.toString();
      if (lessonId != null) {
        _progress[lessonId] = Map<String, dynamic>.from(data);
      }
      return const {};
    }
    if (_matches(segments, ['me', 'quiz-attempts'])) {
      final id = data['id']?.toString();
      // idempotency: نفس المعرّف لا يُسجَّل مرتين.
      if (id != null && !_attempts.any((item) => item['id'] == id)) {
        _attempts.add(Map<String, dynamic>.from(data));
      }
      return const {};
    }

    throw NotFoundException(details: 'POST $path');
  }

  @override
  Future<Map<String, dynamic>> put(String path, {Object? body}) async {
    await _latency();
    final segments = _segments(path);
    final data = _asMap(body);

    if (segments.length == 2 && segments[0] == 'subjects') {
      final subject = _findById(_subjects, segments[1]);
      if (subject == null) throw const NotFoundException();
      subject
        ..['title'] = data['title'] ?? subject['title']
        ..['description'] = data['description']
        ..['updated_at'] = _now();
      return Map<String, dynamic>.from(subject);
    }

    if (segments.length == 2 && segments[0] == 'lessons') {
      final lesson = _findById(_lessons, segments[1]);
      if (lesson == null) throw const NotFoundException();
      for (final key in ['title', 'summary', 'level', 'is_published']) {
        if (data.containsKey(key)) lesson[key] = data[key];
      }
      lesson['updated_at'] = _now();
      return Map<String, dynamic>.from(lesson);
    }

    if (segments.length == 2 && segments[0] == 'blocks') {
      for (final entry in _blocks.entries) {
        final block = _findById(entry.value, segments[1]);
        if (block == null) continue;
        block
          ..['data'] = _asMap(data['data'])
          ..['updated_at'] = _now();
        return Map<String, dynamic>.from(block);
      }
      throw const NotFoundException();
    }

    // /me/levels/{subjectId}
    if (segments.length == 3 && segments[0] == 'me' && segments[1] == 'levels') {
      final subjectId = segments[2];
      _levels[subjectId] = {
        'subject_id': subjectId,
        'level': data['level'],
        'updated_at': _now(),
      };
      return const {};
    }

    throw NotFoundException(details: 'PUT $path');
  }

  @override
  Future<Map<String, dynamic>> patch(String path, {Object? body}) =>
      put(path, body: body);

  @override
  Future<void> delete(String path, {Object? body}) async {
    await _latency();
    final segments = _segments(path);

    if (segments.length == 2 && segments[0] == 'subjects') {
      final subjectId = segments[1];
      _subjects.removeWhere((item) => item['id'] == subjectId);
      final removed = _lessons
          .where((item) => item['subject_id'] == subjectId)
          .map((item) => item['id'] as String)
          .toList();
      _lessons.removeWhere((item) => item['subject_id'] == subjectId);
      for (final lessonId in removed) {
        _blocks.remove(lessonId);
      }
      return;
    }

    if (segments.length == 2 && segments[0] == 'lessons') {
      _lessons.removeWhere((item) => item['id'] == segments[1]);
      _blocks.remove(segments[1]);
      return;
    }

    if (segments.length == 2 && segments[0] == 'blocks') {
      for (final entry in _blocks.entries) {
        final before = entry.value.length;
        entry.value.removeWhere((item) => item['id'] == segments[1]);
        if (entry.value.length != before) {
          _syncBlocksCount(entry.key);
          return;
        }
      }
      throw const NotFoundException();
    }

    throw NotFoundException(details: 'DELETE $path');
  }

  // -------------------------------------------------------------- مساعدات

  Map<String, dynamic> _login(Map<String, dynamic> data) {
    final email = (data['email'] ?? '').toString().trim().toLowerCase();
    final password = (data['password'] ?? '').toString();

    if (password != DemoUsers.password) {
      throw const UnauthorizedException();
    }
    final user = switch (email) {
      DemoUsers.teacherEmail => DemoUsers.teacher,
      DemoUsers.studentEmail => DemoUsers.student,
      _ => null,
    };
    if (user == null) throw const UnauthorizedException();

    _currentUser = Map<String, dynamic>.from(user);
    return {
      'token': 'demo-token-${user['id']}',
      'user': Map<String, dynamic>.from(user),
    };
  }

  /// إحصائيات محسوبة: أرقام أساسية + تقدّم التلميذ الحقيقي في هذه الجلسة.
  Map<String, dynamic> _stats() {
    final lessons = <Map<String, dynamic>>[];
    var scoreSum = 0.0;
    var scoreCount = 0;

    for (final lesson in _lessons) {
      final lessonId = lesson['id']! as String;
      final baseline = demoLessonStatsBaseline[lessonId] ?? const [0, 0];
      var started = baseline[0];
      var completed = baseline[1];

      // تقدّم حساب التلميذ التجريبي يُضاف فوق الأرقام الأساسية.
      final progress = _progress[lessonId];
      if (progress != null) {
        started += 1;
        if (progress['status'] == 'completed') completed += 1;
      }

      final attempts =
          _attempts.where((item) => item['lesson_id'] == lessonId).toList();
      final correct =
          attempts.where((item) => item['is_correct'] == true).length;
      final double? quizScore =
          attempts.isEmpty ? null : correct / attempts.length;
      if (quizScore != null) {
        scoreSum += quizScore;
        scoreCount += 1;
      }

      final subject = _findById(_subjects, lesson['subject_id'] as String);

      lessons.add({
        'lesson_id': lessonId,
        'lesson_title': lesson['title'],
        'subject_title': subject?['title'] ?? '',
        'completion_rate':
            started == 0 ? 0.0 : (completed / started).clamp(0.0, 1.0),
        'average_quiz_score': quizScore,
        'students_started': started,
        'students_completed': completed,
      });
    }

    return {
      'students_count': demoStudentsCount,
      'subjects_count': _subjects.length,
      'lessons_count': _lessons.length,
      'average_quiz_score': scoreCount == 0 ? null : scoreSum / scoreCount,
      'lessons': lessons,
    };
  }

  void _syncBlocksCount(String lessonId) {
    final lesson = _findById(_lessons, lessonId);
    if (lesson == null) return;
    lesson['blocks_count'] = _blocks[lessonId]?.length ?? 0;
  }

  void _applyOrder({
    required List<String> ids,
    required List<Map<String, dynamic>> items,
  }) {
    for (var i = 0; i < ids.length; i++) {
      final item = _findById(items, ids[i]);
      if (item != null) item['position'] = i;
    }
  }

  static Map<String, dynamic>? _findById(
    List<Map<String, dynamic>> items,
    String id,
  ) {
    for (final item in items) {
      if (item['id'] == id) return item;
    }
    return null;
  }

  static List<String> _segments(String path) => path
      .split('?')
      .first
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toList();

  static bool _matches(List<String> segments, List<String> expected) {
    if (segments.length != expected.length) return false;
    for (var i = 0; i < segments.length; i++) {
      if (segments[i] != expected[i]) return false;
    }
    return true;
  }

  static Map<String, dynamic> _asMap(Object? body) =>
      body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};

  static List<String> _stringList(Object? value) =>
      value is List ? value.map((item) => item.toString()).toList() : const [];

  static int _byPosition(Map<String, dynamic> a, Map<String, dynamic> b) =>
      ((a['position'] as num?)?.toInt() ?? 0)
          .compareTo((b['position'] as num?)?.toInt() ?? 0);
}
