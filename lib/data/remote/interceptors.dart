import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:miyu/core/app_prefs.dart';
import 'package:miyu/data/remote/api_config.dart';

/// Auth persistence + interceptor. Retry only for idempotent GETs.
class AuthInterceptor extends Interceptor {
  static const String _kTokenKey = 'account_token';
  static const String _kUsernameKey = 'account_username';

  static Future<String?> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kTokenKey);
  }

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await loadToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    options.headers.addAll(ApiConfig.defaultHeaders());
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    handler.next(response);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    // Token refresh supported by AuthService via onError hook.
    handler.next(err);
  }
}

/// Non-breaking retry: only retries GET on network error.
class RetryOnNetworkInterceptor extends Interceptor {
  static const int maxRetries = 2;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.type == DioExceptionType.connectionTimeout || err.type == DioExceptionType.other) {
      final status = err.response?.statusCode;
      if (status == null || (status >= 500 && status < 600)) {
        handler.next(err); // actual retry performed by callers via retryGet
      }
    }
    handler.next(err);
  }
}

/// Logging interceptor (only in debug builds).
class LoggingInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('[dio] ERROR: ${err.type} ${err.message}');
    }
    handler.next(err);
  }
}
