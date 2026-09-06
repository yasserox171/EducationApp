import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/user.dart';

class AuthApi {
  const AuthApi(this._client);

  final ApiClient _client;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final json = await _client.post(
      ApiEndpoints.login,
      body: {'email': email, 'password': password},
    );
    return AuthSession.fromJson(json);
  }

  Future<AppUser> me() async {
    final json = await _client.getObject(ApiEndpoints.me);
    return AppUser.fromJson(json);
  }

  /// إبطال الرمز على الخادم. الفشل هنا غير حرج: الخروج المحلي يتم دائمًا.
  Future<void> logout() => _client.post(ApiEndpoints.logout);
}
