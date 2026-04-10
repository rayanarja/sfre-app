import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../network/api_client.dart';

/// Riverpod provider
final appProvider = ChangeNotifierProvider<AppProvider>((ref) => AppProvider());

/// AppProvider — يدير الثيم واللغة
class AppProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  String _locale = 'ar';
  int? _userId;

  ThemeMode get themeMode => _themeMode;
  String get locale => _locale;
  bool get isDark => _themeMode == ThemeMode.dark;
  bool get isArabic => _locale == 'ar';
  AppLocalizations get l10n => AppLocalizations(_locale);
  TextDirection get textDirection =>
      _locale == 'ar' ? TextDirection.rtl : TextDirection.ltr;

  /// تحميل التفضيلات
  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString('theme') ?? 'light';
    final lang = prefs.getString('language') ?? 'ar';
    _themeMode = theme == 'dark' ? ThemeMode.dark : ThemeMode.light;
    _locale = lang;
    AppLocalizations.setLocale(lang);
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', mode == ThemeMode.dark ? 'dark' : 'light');
    notifyListeners();
    _syncToServer();
  }

  Future<void> toggleTheme() async {
    await setTheme(_themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> setLocale(String newLocale) async {
    if (newLocale != 'ar' && newLocale != 'en') return;
    _locale = newLocale;
    AppLocalizations.setLocale(newLocale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', newLocale);
    notifyListeners();
    _syncToServer();
  }

  Future<void> toggleLocale() async {
    await setLocale(_locale == 'ar' ? 'en' : 'ar');
  }

  void setUserId(int id) {
    _userId = id;
  }

  Future<void> _syncToServer() async {
    if (_userId == null) return;
    try {
      final api = ApiClient();
      await api.dio.put('/users/$_userId', data: {
        'language': _locale,
        'theme': _themeMode == ThemeMode.dark ? 'dark' : 'light',
      });
    } catch (_) {}
  }
}
