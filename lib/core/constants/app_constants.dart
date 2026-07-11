
import 'dart:io';

class AppConstants {
 
static const String _productionUrl = 'https://sfre-backend-b850.onrender.com/api';
  static String get baseUrl {
    if (_productionUrl.isNotEmpty) return _productionUrl;
    
    if (Platform.isAndroid) {
      const bool isEmulator = bool.fromEnvironment('IS_EMULATOR', defaultValue: false);
      if (isEmulator) {
        return 'http://10.0.2.2:5000/api';
      }
      return 'http://10.100.134.36:5000/api';
    }
    return 'http://localhost:5000/api';
  }

  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String roleKey = 'user_role';
}