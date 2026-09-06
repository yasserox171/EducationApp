import 'package:dio/dio.dart';

import '../config/env.dart';
import '../error/app_exception.dart';
import '../error/error_mapper.dart';
import '../utils/logger.dart';
import 'auth_interceptor.dart';

/// غلاف رقيق حول Dio: يوحّد الترويسات، ويحوّل كل خطأ إلى [AppException].
///
/// كل ما تحت `data/remote/` يستعمل هذا الصنف ولا يلمس Dio مباشرة إلا في
/// حالة الرفع (حيث نحتاج `onSendProgress` و`CancelToken`).
class ApiClient {
  ApiClient({required this.dio});

  final Dio dio;

  factory ApiClient.create({
    required String? Function() tokenProvider,
    required void Function() onUnauthorized,
    Dio? dioOverride,
  }) {
    final dio = dioOverride ??
        Dio(
          BaseOptions(
            baseUrl: Env.baseUrl,
            connectTimeout: Env.connectTimeout,
            receiveTimeout: Env.receiveTimeout,
            contentType: Headers.jsonContentType,
            responseType: ResponseType.json,
            // نتولّى تحويل رموز الحالة إلى استثناءات بأنفسنا.
            validateStatus: (status) => status != null && status < 400,
          ),
        );

    dio.interceptors.add(
      AuthInterceptor(
        tokenProvider: tokenProvider,
        onUnauthorized: onUnauthorized,
      ),
    );

    if (Env.verboseHttpLogs) {
      dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (line) => Log.d('HTTP', line.toString()),
        ),
      );
    }

    return ApiClient(dio: dio);
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (error, stackTrace) {
      Log.e(
        'ApiClient',
        error.requestOptions.path,
        error: error,
        stackTrace: stackTrace,
      );
      throw ErrorMapper.fromDio(error);
    } catch (error, stackTrace) {
      Log.e('ApiClient', 'unexpected', error: error, stackTrace: stackTrace);
      throw ErrorMapper.fromAny(error, stackTrace);
    }
  }

  Future<Map<String, dynamic>> getObject(
    String path, {
    Map<String, dynamic>? query,
  }) =>
      _guard(() async {
        final response = await dio.get<dynamic>(path, queryParameters: query);
        return _asObject(response.data);
      });

  Future<List<Map<String, dynamic>>> getList(
    String path, {
    Map<String, dynamic>? query,
    String dataKey = 'data',
  }) =>
      _guard(() async {
        final response = await dio.get<dynamic>(path, queryParameters: query);
        return _asList(response.data, dataKey);
      });

  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) =>
      _guard(() async {
        final response =
            await dio.post<dynamic>(path, data: body, queryParameters: query);
        return _asObject(response.data);
      });

  Future<Map<String, dynamic>> put(String path, {Object? body}) =>
      _guard(() async {
        final response = await dio.put<dynamic>(path, data: body);
        return _asObject(response.data);
      });

  Future<Map<String, dynamic>> patch(String path, {Object? body}) =>
      _guard(() async {
        final response = await dio.patch<dynamic>(path, data: body);
        return _asObject(response.data);
      });

  Future<void> delete(String path, {Object? body}) => _guard(() async {
        await dio.delete<dynamic>(path, data: body);
      });

  /// يقبل ردًّا على شكل `{...}` أو `{"data": {...}}` أو ردًّا فارغًا (204).
  static Map<String, dynamic> _asObject(dynamic data) {
    if (data == null || (data is String && data.isEmpty)) {
      return <String, dynamic>{};
    }
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final inner = map['data'];
      if (inner is Map && map.length <= 2) {
        return Map<String, dynamic>.from(inner);
      }
      return map;
    }
    throw const ServerException(
      message: 'رد الخادم غير متوقّع.',
      details: 'expected object',
    );
  }

  /// يقبل ردًّا على شكل `[...]` أو `{"data": [...]}`.
  static List<Map<String, dynamic>> _asList(dynamic data, String dataKey) {
    final raw = data is Map ? data[dataKey] : data;
    if (raw is! List) {
      throw const ServerException(
        message: 'رد الخادم غير متوقّع.',
        details: 'expected list',
      );
    }
    return raw
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
  }
}
