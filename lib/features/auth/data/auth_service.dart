import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/models/user_model.dart';

class AuthService {
  final _api = ApiClient();

  // تسجيل دخول بالإيميل (راكب)
  Future<UserModel> login(String email, String password) async {
    try {
      final response = await _api.dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );

      final token = response.data['token'];
      final user = UserModel.fromJson(response.data['user']);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.tokenKey, token);
      await prefs.setString(AppConstants.userKey, jsonEncode(response.data['user']));
      await prefs.setString(AppConstants.roleKey, user.role);

      return user;
    } catch (e) {
      rethrow;
    }
  }

  // تسجيل دخول برقم الهاتف (سائق)
  Future<UserModel> loginByPhone(String phone, String password) async {
    try {
      final response = await _api.dio.post(
        '/auth/login-phone',
        data: {'phone': phone, 'password': password},
      );

      final token = response.data['token'];
      final user = UserModel.fromJson(response.data['user']);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.tokenKey, token);
      await prefs.setString(AppConstants.userKey, jsonEncode(response.data['user']));
      await prefs.setString(AppConstants.roleKey, user.role);

      // حفظ بيانات السائق
      if (response.data['driver'] != null) {
        await prefs.setString('driver_data', jsonEncode(response.data['driver']));
      }

      return user;
    } catch (e) {
      rethrow;
    }
  }

  // تسجيل حساب جديد (راكب)
  Future<UserModel> register({
    required String username,
    required String email,
    required String password,
    String? phone,
    required String role,
  }) async {
    try {
      await _api.dio.post(
        '/auth/register',
        data: {
          'username': username,
          'email': email,
          'password': password,
          'phone': phone,
          'role': role,
        },
      );

      final loginResult = await login(email, password);
      return loginResult;
    } catch (e) {
      rethrow;
    }
  }

  // تسجيل خروج
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.userKey);
    await prefs.remove(AppConstants.roleKey);
    await prefs.remove('driver_data');
  }

  // جيب المستخدم المحفوظ
  Future<UserModel?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(AppConstants.userKey);
    if (userJson == null) return null;
    return UserModel.fromJson(jsonDecode(userJson));
  }

  // هل في توكن محفوظ؟
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.tokenKey) != null;
  }
  


}