import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/enums.dart';
import '../models/progress.dart';

/// مزامنة تقدّم التلميذ ونتائج الكويزات ومستويات المواد.
class ProgressApi {
  const ProgressApi(this._client);

  final ApiClient _client;

  /// سحب كل تقدّم التلميذ من الخادم (عند الدخول أو عند الإقلاع مع اتصال).
  Future<List<LessonProgress>> fetchMyProgress() async {
    final list = await _client.getList(ApiEndpoints.myProgress);
    return list.map(LessonProgress.fromJson).toList(growable: false);
  }

  /// دفع تحديث تقدّم درس واحد.
  Future<void> pushProgress(Map<String, dynamic> payload) =>
      _client.post(ApiEndpoints.progressSync, body: payload);

  /// دفع محاولة كويز. `id` المحلي يُستعمل كمفتاح idempotency حتى لا تُحتسب
  /// المحاولة مرتين إن أُعيد الإرسال.
  Future<void> pushQuizAttempt(Map<String, dynamic> payload) =>
      _client.post(ApiEndpoints.quizAttempts, body: payload);

  Future<List<SubjectLevelChoice>> fetchMyLevels() async {
    final list = await _client.getList(ApiEndpoints.myLevels);
    return list.map(SubjectLevelChoice.fromJson).toList(growable: false);
  }

  Future<void> pushLevel({
    required String subjectId,
    required LessonLevel level,
  }) =>
      _client.put(
        ApiEndpoints.subjectLevel(subjectId),
        body: {'level': level.wire},
      );
}
