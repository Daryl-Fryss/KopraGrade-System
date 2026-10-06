import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';

class AuthState {
  final AppUser? user;
  final bool initializing; // true while a saved login is being checked
  const AuthState({this.user, this.initializing = false});
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._api, this._service) : super(const AuthState(initializing: true)) {
    _api.onUnauthorized = logout;
    _restore();
  }

  final ApiClient _api;
  final AuthService _service;
  static const _tokenKey = 'kopragrade_token';

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_tokenKey);
    if (saved == null) {
      state = const AuthState();
      return;
    }
    _api.token = saved;
    try {
      state = AuthState(user: await _service.me());
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await prefs.remove(_tokenKey);
      }
      _api.token = null;
      state = const AuthState();
    }
  }

  Future<void> login(String email, String password) async {
    final result = await _service.login(email, password);
    _api.token = result.token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, result.token);
    state = AuthState(user: result.user);
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    await _service.register(name: name, email: email, password: password, role: role);
    await login(email, password);
  }

  Future<void> updateProfile({required String name, String? contact}) async {
    final user = await _service.updateProfile(name: name, contact: contact);
    state = AuthState(user: user);
  }

  Future<void> logout() async {
    _api.token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    state = const AuthState();
  }
}
