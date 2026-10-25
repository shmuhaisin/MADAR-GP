import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../storage/token_storage.dart';
import 'endpoints.dart';

class ApiClient {
  final Dio _dio;
  final TokenStorage _tokenStorage = TokenStorage();

  ApiClient({String? baseUrl})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? Endpoints.baseUrl,
            headers: {'Content-Type': 'application/json'},
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final needsAuth = (options.extra['auth'] as bool?) ?? true;

          // Always remove old Authorization first.
          // This prevents the old account token from staying in memory.
          options.headers.remove('Authorization');

          if (needsAuth) {
            final token = await _tokenStorage.readToken();

            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }

          if (options.data != null) {
            debugPrint('body=${options.data}');
          }

          return handler.next(options);
        },
        onError: (e, handler) async {
          debugPrint('API ERROR: ${e.toString()}');

          // If backend rejects the token, clear it locally.
          if (e.response?.statusCode == 401) {
            await _tokenStorage.clearToken();
          }

          return handler.next(e);
        },
      ),
    );
  }

  Dio get dio => _dio;

  Future<Map<String, dynamic>> get(String path, {bool auth = true}) =>
      getMap(path, auth: auth);

  Future<Map<String, dynamic>> post(
    String path, {
    dynamic data,
    bool auth = true,
  }) =>
      postMap(path, data: data, auth: auth);

  Future<Map<String, dynamic>> patch(
    String path, {
    dynamic data,
    bool auth = true,
  }) =>
      patchMap(path, data: data, auth: auth);

  Future<Map<String, dynamic>> delete(String path, {bool auth = true}) =>
      deleteMap(path, auth: auth);

  Future<Map<String, dynamic>> getMap(String path, {bool auth = true}) async {
    final res = await _dio.get(
      path,
      options: Options(extra: {'auth': auth}),
    );

    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> postMap(
    String path, {
    dynamic data,
    bool auth = true,
  }) async {
    final res = await _dio.post(
      path,
      data: data,
      options: Options(extra: {'auth': auth}),
    );

    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> patchMap(
    String path, {
    dynamic data,
    bool auth = true,
  }) async {
    final res = await _dio.patch(
      path,
      data: data,
      options: Options(extra: {'auth': auth}),
    );

    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> deleteMap(String path, {bool auth = true}) async {
    final res = await _dio.delete(
      path,
      options: Options(extra: {'auth': auth}),
    );

    return _asMap(res.data);
  }

  Future<List<dynamic>> getList(String path, {bool auth = true}) async {
    final res = await _dio.get(
      path,
      options: Options(extra: {'auth': auth}),
    );

    return _asList(res.data);
  }

  Future<List<dynamic>> postList(
    String path, {
    dynamic data,
    bool auth = true,
  }) async {
    final res = await _dio.post(
      path,
      data: data,
      options: Options(extra: {'auth': auth}),
    );

    return _asList(res.data);
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);

    throw Exception('Expected JSON object (Map) but got: ${data.runtimeType}');
  }

  List<dynamic> _asList(dynamic data) {
    if (data is List) return data;

    throw Exception('Expected JSON array (List) but got: ${data.runtimeType}');
  }

  static String formatDioError(Object e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      final data = e.response?.data;

      return 'HTTP $status: $data';
    }

    return e.toString();
  }
}