import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';

class TokenStorage {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  static const _rememberMeKey = 'remember_me';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Simpan Token
  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: _tokenKey, value: token);
  }

  // Ambil Token
  Future<String?> getToken() async {
    return await _secureStorage.read(key: _tokenKey);
  }

  // Simpan Data User
  Future<void> saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  // Ambil Data User
  Future<UserModel?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_userKey);
    if (jsonStr == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // Hapus Sesi (Logout)
  Future<void> clearSession() async {
    await _secureStorage.delete(key: _tokenKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }

  // Remember Me Storage
  Future<void> saveRememberMe({required String username, required String password}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rememberMeKey, jsonEncode({'username': username, 'password': password}));
  }

  Future<Map<String, String>?> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_rememberMeKey);
    if (data == null) return null;
    try {
      final map = jsonDecode(data) as Map<String, dynamic>;
      return {
        'username': map['username'] as String? ?? '',
        'password': map['password'] as String? ?? '',
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> clearRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rememberMeKey);
  }
}
