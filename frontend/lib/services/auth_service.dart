import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/app_user.dart';

class AuthService {
  AuthService(this._api);
  final ApiClient _api;

  /// POST /api/auth/register
  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      await _api.dio.post('/auth/register', data: {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'role': role,
      });
    } on DioException catch (e) {
      throw ApiException.from(e);
    }
  }

  /// POST /api/auth/login  -> token + user
  Future<({String token, AppUser user})> login(String email, String password) async {
    try {
      final res = await _api.dio.post('/auth/login', data: {'email': email.trim(), 'password': password});
      final data = res.data as Map<String, dynamic>;
      return (token: data['token'] as String, user: AppUser.fromJson(data['user'] as Map<String, dynamic>));
    } on DioException catch (e) {
      throw ApiException.from(e);
    }
  }

  /// GET /api/users/me
  Future<AppUser> me() async {
    try {
      final res = await _api.dio.get('/users/me');
      return AppUser.fromJson((res.data as Map<String, dynamic>)['user'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.from(e);
    }
  }

  /// PUT /api/users/me
  Future<AppUser> updateProfile({required String name, String? contact}) async {
    try {
      final res = await _api.dio.put('/users/me', data: {'name': name.trim(), 'contact': contact?.trim()});
      return AppUser.fromJson((res.data as Map<String, dynamic>)['user'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.from(e);
    }
  }
}
