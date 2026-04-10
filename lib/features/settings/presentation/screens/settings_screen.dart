import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/app_provider.dart';
import '../../../../shared/models/user_model.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user_data');
    if (userJson != null) {
      setState(() => _user = UserModel.fromJson(jsonDecode(userJson)));
    }
  }

  Future<void> _logout() async {
    final provider = ref.read(appProvider);
    final l = provider.l10n;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.t('logout')),
        content: Text(provider.isArabic
            ? 'هل أنت متأكد من تسجيل الخروج؟'
            : 'Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.t('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.t('logout'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      // أعد تحميل التفضيلات (تصير default)
      await ref.read(appProvider).loadPreferences();
      if (!mounted) return;
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(appProvider);
    final l = provider.l10n;
    final dark = provider.isDark;

    return Directionality(
      textDirection: provider.textDirection,
      child: Scaffold(
        backgroundColor: dark ? const Color(0xFF121212) : AppColors.background,
        appBar: AppBar(
          title: Text(l.t('settings')),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // معلومات المستخدم
            if (_user != null) _buildUserCard(dark),
            const SizedBox(height: 20),

            // المظهر
            _sectionTitle(l.t('appearance'), Icons.palette_outlined, dark),
            const SizedBox(height: 8),
            _card(dark, children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(dark ? Icons.dark_mode : Icons.light_mode, color: dark ? Colors.amber : AppColors.warning),
                    const SizedBox(width: 12),
                    Expanded(child: Text(dark ? l.t('dark_mode') : l.t('light_mode'),
                        style: TextStyle(fontSize: 15, color: dark ? Colors.white : AppColors.textPrimary))),
                    Switch(value: dark, onChanged: (_) => provider.toggleTheme(), activeColor: AppColors.primary),
                  ],
                ),
              ),
            ]),

            const SizedBox(height: 16),

            // اللغة
            _sectionTitle(l.t('language'), Icons.language, dark),
            const SizedBox(height: 8),
            _card(dark, children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.language, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(child: Text(l.t('language'),
                        style: TextStyle(fontSize: 15, color: dark ? Colors.white : AppColors.textPrimary))),
                    Container(
                      decoration: BoxDecoration(
                        color: dark ? Colors.white10 : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        _langBtn('العربية', 'ar', provider, dark),
                        _langBtn('English', 'en', provider, dark),
                      ]),
                    ),
                  ],
                ),
              ),
            ]),

            const SizedBox(height: 16),

            // الحساب
            _sectionTitle(l.t('account'), Icons.person_outline, dark),
            const SizedBox(height: 8),
            _card(dark, children: [
              _tile(Icons.edit_outlined, l.t('edit_profile'), AppColors.primary, () => context.push('/edit-profile'), dark, provider.isArabic),
              Divider(height: 1, color: dark ? const Color(0xFF333333) : const Color(0xFFE5E7EB)),
              _tile(Icons.lock_outline, l.t('change_password'), AppColors.warning, () => context.push('/change-password'), dark, provider.isArabic),
              Divider(height: 1, color: dark ? const Color(0xFF333333) : const Color(0xFFE5E7EB)),
              _tile(Icons.logout, l.t('logout'), AppColors.error, _logout, dark, provider.isArabic),
            ]),

            const SizedBox(height: 24),
            Center(child: Text('${l.t('version')} 1.0.0', style: TextStyle(color: dark ? Colors.white38 : AppColors.textHint, fontSize: 12))),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(bool dark) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF1A237E)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
          child: Center(child: Text(_user!.username.substring(0, 1).toUpperCase(), style: TextStyle(color: Theme.of(context).cardColor, fontSize: 24, fontWeight: FontWeight.bold))),
        ),
        SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_user!.username, style: TextStyle(color: Theme.of(context).cardColor, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(_user!.email, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
        ])),
      ]),
    );
  }

  Widget _sectionTitle(String title, IconData icon, bool dark) {
    return Row(children: [
      Icon(icon, size: 18, color: dark ? Colors.white70 : AppColors.textSecondary),
      const SizedBox(width: 8),
      Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: dark ? Colors.white70 : AppColors.textSecondary)),
    ]);
  }

  Widget _card(bool dark, {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dark ? Colors.white12 : const Color(0xFFE5E7EB)),
      ),
      child: Column(children: children),
    );
  }

  Widget _langBtn(String label, String locale, AppProvider provider, bool dark) {
    final sel = provider.locale == locale;
    return GestureDetector(
      onTap: () => provider.setLocale(locale),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: sel ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        child: Text(label, style: TextStyle(color: sel ? Colors.white : (dark ? Colors.white60 : AppColors.textSecondary), fontSize: 13, fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }

  Widget _tile(IconData icon, String title, Color color, VoidCallback onTap, bool dark, bool isArabic) {
    return ListTile(
      leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
      title: Text(title, style: TextStyle(fontSize: 15, color: dark ? Colors.white : AppColors.textPrimary)),
      trailing: Icon(isArabic ? Icons.chevron_left : Icons.chevron_right, color: dark ? Colors.white30 : AppColors.textHint),
      onTap: onTap,
    );
  }
}
