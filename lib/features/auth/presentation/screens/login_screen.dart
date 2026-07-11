import '../../../../core/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../features/auth/data/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isDriverMode = false;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (_isDriverMode) {
        await _authService.loginByPhone(_phoneController.text.trim(), _passwordController.text);
        if (!mounted) return;
        final prefs = await SharedPreferences.getInstance();
        final userData = jsonDecode(prefs.getString('user_data') ?? '{}');
        if (userData['must_change_password'] == true) {
          context.go('/change-password');
        } else {
          context.go('/driver');
        }
      } else {
        final user = await _authService.login(_emailController.text.trim(), _passwordController.text);
        if (!mounted) return;
        if (user.isDriver) {
          context.go('/driver');
        } else {
          context.go('/passenger');
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isDriverMode ? AppLocalizations.current.tr('wrong_credentials') : AppLocalizations.current.tr('wrong_credentials')),
          backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 48),
                Center(child: Column(children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(color: _isDriverMode ? AppColors.driverColor : AppColors.primary, borderRadius: BorderRadius.circular(20)),
                    child: Icon(Icons.directions_bus_rounded, color: Theme.of(context).cardColor, size: 48),
                  ),
                  SizedBox(height: 16),
                  Text(AppLocalizations.current.tr('welcome'), style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: null)),
                  SizedBox(height: 8),
                  Text(_isDriverMode ? AppLocalizations.current.tr('login_as_driver_desc') : AppLocalizations.current.tr('login_continue'), style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                ])),

                const SizedBox(height: 32),

                Container(
                  decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
                  padding: EdgeInsets.all(4),
                  child: Row(children: [
                    _buildTab(false, Icons.person, 'راكب', AppColors.primary),
                    _buildTab(true, Icons.directions_bus, 'سائق', AppColors.driverColor),
                  ]),
                ),

                SizedBox(height: 28),

                if (!_isDriverMode) ...[
                  Text(AppLocalizations.current.tr('email'), style: TextStyle(fontWeight: FontWeight.w600, color: null)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(hintText: 'example@email.com', prefixIcon: Icon(Icons.email_outlined)),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'الرجاء إدخال الإيميل';
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) return 'إيميل غير صحيح';
                      return null;
                    },
                  ),
                ] else ...[
                  Text(AppLocalizations.current.tr('phone'), style: TextStyle(fontWeight: FontWeight.w600, color: null)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(hintText: '09xxxxxxxx', prefixIcon: Icon(Icons.phone_outlined)),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'الرجاء إدخال رقم الهاتف';
                      final cleaned = value.replaceAll(RegExp(r'[\s\-()]'), '');
                      final patterns = [RegExp(r'^09\d{8}$'), RegExp(r'^\+9639\d{8}$'), RegExp(r'^009639\d{8}$'), RegExp(r'^9639\d{8}$')];
                      if (!patterns.any((p) => p.hasMatch(cleaned))) return 'رقم سوري غير صحيح';
                      return null;
                    },
                  ),
                ],

                SizedBox(height: 20),

                Text(AppLocalizations.current.tr('password'), style: TextStyle(fontWeight: FontWeight.w600, color: null)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'الرجاء إدخال كلمة المرور';
                    if (value.length < 6) return 'على الأقل 6 أحرف';
                    return null;
                  },
                ),

                SizedBox(height: 32),

                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(backgroundColor: _isDriverMode ? AppColors.driverColor : null),
                  child: _isLoading
                      ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Theme.of(context).cardColor, strokeWidth: 2))
                      : Text(_isDriverMode ? AppLocalizations.current.tr('login_as_driver') : AppLocalizations.current.tr('login')),
                ),

                SizedBox(height: 16),

                if (!_isDriverMode)
                  Row(mainAxisAlignment: MainAxisAlignment.center, textDirection: TextDirection.rtl, children: [
                    Text(AppLocalizations.current.tr('no_account'), style: TextStyle(color: AppColors.textSecondary)),
                    GestureDetector(onTap: () => context.go('/register'), child: Text(AppLocalizations.current.tr('register_now'), style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600))),
                  ]),

                if (_isDriverMode)
                  _buildInfoBox('بيانات الدخول ستصلك من الإدارة  (رقم الهاتف + كلمة المرور)', AppColors.driverColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTab(bool isDriver, IconData icon, String label, Color color) {
    final isActive = _isDriverMode == isDriver;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() { _isDriverMode = isDriver; _passwordController.clear(); }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18, color: isActive ? color : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: isActive ? color : AppColors.textSecondary)),
          ]),
        ),
      ),
    );
  }

  Widget _buildInfoBox(String text, Color color) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
        child: Row(textDirection: TextDirection.rtl, children: [
          Icon(Icons.info_outline, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 12), textAlign: TextAlign.right)),
        ]),
      ),
    );
  }
}
