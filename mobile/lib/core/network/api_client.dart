import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../config/app_config.dart';
import '../errors/api_exception.dart';
import '../storage/secure_store.dart';

typedef SessionExpiredCallback = Future<void> Function();

/// Dio wrapper that:
///  * attaches the bearer token,
///  * transparently refreshes once on 401 and replays the request,
///  * normalises every failure into [ApiException],
///  * notifies the app when the session is truly gone.
class ApiClient {
  ApiClient({required SecureStore secureStore, String? serverUrl, Dio? dio})
      : _secureStore = secureStore,
        _dio = dio ?? _buildDio(AppConfig.resolvedApiBaseUrl(serverUrl)),
        // Refresh uses its own client so a stale bearer token is never resent.
        _authDio = _buildDio(AppConfig.resolvedApiBaseUrl(serverUrl));

  static Dio _buildDio(String baseUrl) => Dio(
        BaseOptions(
          baseUrl: '$baseUrl/api',
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 60),
          headers: {'Accept': 'application/json'},
          // Non-2xx must surface as DioException so the 401-refresh path runs.
          validateStatus: (status) => status != null && status >= 200 && status < 300,
        ),
      );

  final Dio _dio;
  final Dio _authDio;
  final SecureStore _secureStore;

  SessionExpiredCallback? onSessionExpired;
  bool _refreshing = false;
  Future<bool>? _refreshFuture;

  Dio get raw => _dio;

  void setTokens({String? accessToken}) {
    if (accessToken == null) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Bearer $accessToken';
    }
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) =>
      _request(() => _dio.get<dynamic>(path, queryParameters: query));

  Future<Map<String, dynamic>> post(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) =>
      _request(() => _dio.post<dynamic>(path, data: data, queryParameters: query));

  Future<Map<String, dynamic>> patch(String path, {Object? data}) =>
      _request(() => _dio.patch<dynamic>(path, data: data));

  Future<Map<String, dynamic>> delete(String path, {Object? data}) =>
      _request(() => _dio.delete<dynamic>(path, data: data));

  /// Multipart upload with progress callback (0..1).
  Future<Map<String, dynamic>> upload(
    String path, {
    required String filePath,
    required String fileName,
    void Function(double progress)? onProgress,
    String field = 'file',
  }) async {
    Response<dynamic>? response;
    try {
      final form = FormData.fromMap({
        field: await MultipartFile.fromFile(filePath, filename: fileName),
      });
      response = await _dio.post<dynamic>(
        path,
        data: form,
        onSendProgress: (sent, total) {
          if (total > 0) onProgress?.call(sent / total);
        },
      );
      return _unwrap(response);
    } on DioException catch (error) {
      throw _mapError(error);
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(message: error.toString(), code: 'UPLOAD_FAILED');
    }
  }

  Future<Map<String, dynamic>> _request(Future<Response<dynamic>> Function() send) async {
    try {
      final response = await send();
      return _unwrap(response);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 401 && !_isRefreshCall(error.requestOptions)) {
        final refreshed = await _tryRefresh();
        if (refreshed) {
          try {
            final retried = await send();
            return _unwrap(retried);
          } on DioException catch (retryError) {
            throw _mapError(retryError);
          }
        }
        await onSessionExpired?.call();
        throw _mapError(error);
      }
      throw _mapError(error);
    } on ApiException catch (error) {
      // Defensive: handles a 401 raised from a pre-validated response body.
      if (error.isUnauthorized && !_refreshing) {
        final refreshed = await _tryRefresh();
        if (refreshed) {
          try {
            final retried = await send();
            return _unwrap(retried);
          } on DioException catch (retryError) {
            throw _mapError(retryError);
          }
        }
        await onSessionExpired?.call();
      }
      rethrow;
    }
  }

  bool _isRefreshCall(RequestOptions options) => options.path.contains('/auth/refresh');

  Future<bool> _tryRefresh() {
    if (_refreshing) {
      return _refreshFuture ?? Future.value(false);
    }
    _refreshing = true;
    _refreshFuture = _performRefresh().whenComplete(() {
      _refreshing = false;
      _refreshFuture = null;
    });
    return _refreshFuture!;
  }

  Future<bool> _performRefresh() async {
    final refreshToken = await _secureStore.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final response = await _authDio.post<dynamic>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final body = response.data;
      if (body is! Map<String, dynamic> || body['success'] != true) return false;
      final data = body['data'] as Map<String, dynamic>?;
      final newAccess = data?['accessToken'] as String?;
      final newRefresh = data?['refreshToken'] as String?;
      if (newAccess == null || newRefresh == null) return false;
      await _secureStore.saveTokens(accessToken: newAccess, refreshToken: newRefresh);
      setTokens(accessToken: newAccess);
      return true;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _unwrap(Response<dynamic> response) {
    final body = response.data;
    final status = response.statusCode ?? 0;
    if (body is Map<String, dynamic>) {
      if (body['success'] == true) return body;
      final error = body['error'];
      if (error is Map<String, dynamic>) {
        throw ApiException(
          message: (error['message'] ?? 'Request failed').toString(),
          code: error['code']?.toString(),
          statusCode: status,
          details: (error['details'] as List?)
              ?.whereType<Map>()
              .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
              .toList(),
        );
      }
      throw ApiException(
        message: (body['message'] ?? 'Request failed').toString(),
        statusCode: status,
      );
    }
    if (status >= 200 && status < 300) {
      return {'success': true, 'data': body};
    }
    throw ApiException(message: 'Unexpected response from server', statusCode: status);
  }

  ApiException _mapError(DioException error) {
    final response = error.response;
    if (response?.data is Map<String, dynamic>) {
      final body = response!.data as Map<String, dynamic>;
      final err = body['error'];
      if (err is Map<String, dynamic>) {
        return ApiException(
          message: (err['message'] ?? 'Request failed').toString(),
          code: err['code']?.toString(),
          statusCode: response.statusCode,
          details: (err['details'] as List?)
              ?.whereType<Map>()
              .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
              .toList(),
        );
      }
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException.network('The request timed out. Please try again.');
      case DioExceptionType.connectionError:
        return ApiException.network('Cannot reach Miyu servers.');
      case DioExceptionType.cancel:
        return ApiException(message: 'Request cancelled', code: 'CANCELLED');
      case DioExceptionType.badCertificate:
        return ApiException.network('Secure connection failed.');
      case DioExceptionType.badResponse:
        return ApiException(
          message: 'Server error (${error.response?.statusCode ?? 'unknown'})',
          statusCode: error.response?.statusCode,
        );
      case DioExceptionType.unknown:
        if (error.error is SocketException) {
          return ApiException.network('No internet connection.');
        }
        return ApiException(message: error.message ?? 'Something went wrong');
      // Handles any enum value added by a future dio release without breaking
      // the build (Dart 3 treats switched enums as exhaustive).
      default:
        return ApiException(
          message: error.message ?? 'Something went wrong',
          statusCode: error.response?.statusCode,
        );
    }
  }
}
