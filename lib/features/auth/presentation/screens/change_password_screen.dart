import '../../../../core/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final api = ApiClient();

      final posJson = prefs.getString('pos_data');
      if (posJson != null) {
        final pos = jsonDecode(posJson);
        await api.dio.post('/pos/change-password', data: {
          'pos_id': pos['id'],
          'old_password': _oldPasswordController.text,
          'new_password': _newPasswordController.text,
        });
        pos['must_change_password'] = false;
        await prefs.setString('pos_data', jsonEncode(pos));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم تغيير كلمة المرور'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating),
        );
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        context.go('/pos');
      } else {
        final userJson = prefs.getString('user_data');
        if (userJson == null) throw Exception('مو مسجل دخول');
        final user = jsonDecode(userJson);
        await api.dio.post('/auth/change-password', data: {
          'user_id': user['id'],
          'old_password': _oldPasswordController.text,
          'new_password': _newPasswordController.text,
        });
        user['must_change_password'] = false;
        await prefs.setString('user_data', jsonEncode(user));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ تم تغيير كلمة المرور'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating),
        );
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        context.go('/driver');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.current.tr('wrong_old_password')), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating),
      );
    }
  }
    @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmController.dispose();
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
              children: [
                const SizedBox(height: 48),

                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.lock_reset_rounded, color: AppColors.warning, size: 48),
                ),
                const SizedBox(height: 16),
                const Text(
                  'غيّر كلمة المرور',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: null),
                ),
                const SizedBox(height: 8),
                const Text(
                  'يجب ان تغيّر كلمة المرور المؤقتة التي أعطاها لك  المدير',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                TextFormField(
                  controller: _oldPasswordController,
                  obscureText: _obscureOld,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور الحالية',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureOld ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscureOld = !_obscureOld),
                    ),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null,
                ),

                SizedBox(height: 16),

                TextFormField(
                  controller: _newPasswordController,
                  obscureText: _obscureNew,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.current.tr('new_password'),
                    prefixIcon: const Icon(Icons.lock_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscureNew = !_obscureNew),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'مطلوب';
                    if (v.length < 6) return 'على الأقل 6 أحرف';
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _confirmController,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'تأكيد كلمة المرور',
                    prefixIcon: const Icon(Icons.lock_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (v) {
                    if (v != _newPasswordController.text) return 'كلمات المرور غير متطابقة';
                    return null;
                  },
                ),

                SizedBox(height: 32),

                ElevatedButton(
                  onPressed: _isLoading ? null : _changePassword,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.driverColor),
                  child: _isLoading
                      ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Theme.of(context).cardColor, strokeWidth: 2))
                      : Text(AppLocalizations.current.tr('change_password')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}