import 'package:dio/dio.dart';
import 'config.dart';

/// A readable error that screens can show directly to the user.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);

  factory ApiException.from(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['error'] is String) {
        return ApiException(data['error'] as String, error.response?.statusCode);
      }
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return ApiException('The server took too long to answer. Please try again.');
        case DioExceptionType.connectionError:
          return ApiException(
              'Cannot reach the server. Check your internet connection and that the API is running.');
        default:
          return ApiException('Something went wrong. Please try again.', error.response?.statusCode);
      }
    }
    return ApiException('Something went wrong. Please try again.');
  }

  @override
  String toString() => message;
}

/// One shared Dio instance that adds the login token to every request.
class ApiClient {
  ApiClient() {
    dio = Dio(BaseOptions(
      baseUrl: '${AppConfig.baseUrl}/api',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 45), // grading can take a moment
      sendTimeout: const Duration(seconds: 45),
    ));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final t = token;
        if (t != null) options.headers['Authorization'] = 'Bearer $t';
        handler.next(options);
      },
      onError: (error, handler) {
        final isAuthCall = error.requestOptions.path.startsWith('/auth');
        if (error.response?.statusCode == 401 && token != null && !isAuthCall) {
          onUnauthorized?.call(); // token expired: send the user back to login
        }
        handler.next(error);
      },
    ));
  }

  late final Dio dio;
  String? token;
  void Function()? onUnauthorized;
}
