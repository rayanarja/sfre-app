// class AppConstants {
//   // رابط الـ backend — غيّر الـ IP لو الـ backend على جهاز ثاني
//   static const String baseUrl = 'http://10.0.2.2:5000/api';

//   // Keys للـ SharedPreferences
//   static const String tokenKey = 'auth_token';
//   static const String userKey = 'user_data';
//   static const String roleKey = 'user_role';
// }
import 'dart:io';

class AppConstants {
  // ═══ غيّر هالرابط لما تنشر على سيرفر سحابي ═══
  // مثال: 'https://your-app.railway.app/api'
static const String _productionUrl = 'https://sfre-backend-b850.onrender.com/api';
  static String get baseUrl {
    // إذا في رابط إنتاج — استخدمو
    if (_productionUrl.isNotEmpty) return _productionUrl;
    
    if (Platform.isAndroid) {
      const bool isEmulator = bool.fromEnvironment('IS_EMULATOR', defaultValue: false);
      if (isEmulator) {
        return 'http://10.0.2.2:5000/api';
      }
      return 'http://192.168.43.36:5000/api';
    }
    return 'http://localhost:5000/api';
  }

  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String roleKey = 'user_role';
}