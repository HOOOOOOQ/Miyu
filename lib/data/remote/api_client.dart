import 'dart:async';
import 'package:dio/dio.dart';
import 'package:miyu/data/remote/api_config.dart';
import 'package:miyu/data/remote/interceptors.dart';

/// Dio-based API client (Task requires Dio). Retry only when safe; auth
/// persistence in AuthInterceptor; token refresh handled by AuthService.
class ApiClient {
  final Dio dio;

  ApiClient({Dio? dio})
      : dio = dio ?? Dio()
          ..options.connectTimeout = ApiConfig.connectTimeout
          ..options.receiveTimeout = ApiConfig.receiveTimeout
          ..options.validateStatus = (int status) => status >= 200 && status < 300
          ..interceptors.add(LoggingInterceptor())
          ..interceptors.add(AuthInterceptor());

  Future<Response<dynamic>> get(String path, {Map<String, dynamic>? queryParameters}) async {
    return dio.get(path, queryParameters: queryParameters);
  }

  Future<Response<dynamic>> post(String path, {Map<String, dynamic>? data, Map<String, dynamic>? queryParameters}) async {
    return dio.post(path, data: data, queryParameters: queryParameters);
  }

  Future<Response<dynamic>> delete(String path) async {
    return dio.delete(path);
  }
}
