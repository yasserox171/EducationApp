import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/teacher_stats.dart';

class StatsApi {
  const StatsApi(this._client);

  final ApiClient _client;

  Future<TeacherStats> fetchTeacherStats() async {
    final json = await _client.getObject(ApiEndpoints.teacherStats);
    return TeacherStats.fromJson(json);
  }
}
