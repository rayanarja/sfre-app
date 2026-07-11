import '../../../../core/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/notification_service.dart';
import 'dart:async';
import 'dart:convert';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../core/network/api_client.dart';

class PassengerHomeScreen extends StatefulWidget {
  const PassengerHomeScreen({super.key});

  @override
  State<PassengerHomeScreen> createState() => _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends State<PassengerHomeScreen> {
  int _currentIndex = 0;
  UserModel? _user;
  List<String> _favorites = [];
  List<String> _recentTrips = [];
  Map<String, dynamic>? _subscription;
  bool _loadingSubscription = true;
  int _unreadNotifications = 0;
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    NotificationService().init(); 
    _loadUser();
    _loadFavorites();
    _startNotificationTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_user != null) _loadSubscription(_user!.id);
  }

  void _startNotificationTimer() {
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (timer) {
        if (_user != null) _loadUnreadNotifications(_user!.id);
      },
    );
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user_data');
    if (userJson != null) {
      final user = UserModel.fromJson(jsonDecode(userJson));
      setState(() => _user = user);
      _loadSubscription(user.id);
      _loadUnreadNotifications(user.id);
    }
  }
int _lastNotifCount = 0;

  Future<void> _loadUnreadNotifications(int userId) async {
    try {
      final api = ApiClient();
      final response = await api.dio.get('/notifications/user/$userId');
      final notifications = List<Map<String, dynamic>>.from(response.data);
      final unread = notifications.where((n) => n['is_read'] == false).length;
      if (mounted) {
      if (unread > _lastNotifCount && _lastNotifCount > 0) {
            final msg = notifications.firstWhere((n) => n['is_read'] == false)['message'] ?? 'إشعار جديد';
            NotificationService().alertUser(title: '🔔 إشعار جديد', body: msg);
          }
        _lastNotifCount = unread;
        setState(() => _unreadNotifications = unread);
      }
    } catch (e) {}
  }  Future<void> _loadSubscription(int userId) async {
    try {
      final api = ApiClient();
      final response = await api.dio.get('/subscriptions/user/$userId');
      final data = response.data;
      if (data != null && data is Map && data['subscription_id'] != null) {
        setState(() {
          _subscription = Map<String, dynamic>.from(data);
          _loadingSubscription = false;
        });
      } else {
        setState(() {
          _subscription = null;
          _loadingSubscription = false;
        });
      }
    } catch (e) {
      setState(() {
        _subscription = null;
        _loadingSubscription = false;
      });
    }
  }

  String _timeRemaining() {
    if (_subscription == null) return '0';
    try {
      final endDate = DateTime.parse(_subscription!['end_date']);
      final diff = endDate.difference(DateTime.now());
      if (diff.inDays <= 0) return 'انتهى';
      return '${diff.inDays} يوم';
    } catch (e) {
      return '0';
    }
  }

  bool _isExpiringSoon() {
    if (_subscription == null) return false;
    try {
      final endDate = DateTime.parse(_subscription!['end_date']);
      return endDate.difference(DateTime.now()).inDays <= 3;
    } catch (e) {
      return false;
    }
  }

  String _subscriptionTypeAr() {
    if (_subscription == null) return 'لا يوجد';
    if (_subscription!['plan'] != null) {
      return _subscription!['plan']['name'] ?? '';
    }
    return '';
  }

  int get _tripsUsed => _subscription?['trips_used'] ?? 0;
  int get _tripsLimit => _subscription?['trips_limit'] ?? 0;
  int get _tripsRemaining => _tripsLimit - _tripsUsed;
  bool get _tripsRunningLow => _tripsLimit > 0 && _tripsRemaining <= (_tripsLimit * 0.1);

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favorites = prefs.getStringList('favorites') ?? [];
      _recentTrips = prefs.getStringList('recent_trips') ?? [];
    });
  }

  Future<void> _removeFavorite(String route) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _favorites.remove(route));
    await prefs.setStringList('favorites', _favorites);
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    context.go('/login');
  }

void _showFamilyDialog() {
    final emailController = TextEditingController();
    final maxUsers = _subscription?['max_users'] ?? 1;
    final subId = _subscription?['subscription_id'];
    List<Map<String, dynamic>> members = [];
    try {
      final raw = _subscription?['family_members'];
      if (raw != null && raw is List) {
        members = raw.map((m) => Map<String, dynamic>.from(m)).toList();
      }
    } catch (e) {
      members = [];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                '👨‍👩‍👧‍👦 إدارة أفراد العائلة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '${members.length} من ${maxUsers - 1} أفراد مضافين',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              SizedBox(height: 16),

              if (members.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(AppLocalizations.current.tr('no_members_yet'), style: TextStyle(color: AppColors.textHint)),
                  ),
                ),

              ...members.map((m) {
                final username = m['user']?['username'] ?? '—';
                final email = m['user']?['email'] ?? '';
                final firstLetter = username.isNotEmpty ? username[0].toUpperCase() : '?';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFF7B1FA2),
                        child: Text(firstLetter, style: TextStyle(color: Theme.of(context).cardColor, fontSize: 12)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(username, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            Text(email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 20),
                        onPressed: () async {
                          try {
                            final api = ApiClient();
                            await api.dio.delete('/subscriptions/family/${m['member_id']}');
                            setSheetState(() => members.removeWhere((x) => x['member_id'] == m['member_id']));
                            if (_user != null) _loadSubscription(_user!.id);
                          } catch (e) {
                            // ignore
                          }
                        },
                      ),
                    ],
                  ),
                );
              }),

              if (members.length < maxUsers - 1) ...[
                SizedBox(height: 12),
                Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: emailController,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          hintText: AppLocalizations.current.tr('member_email'),
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 56,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (emailController.text.isEmpty) return;
                          try {
                            final api = ApiClient();
                            final res = await api.dio.post(
                              '/subscriptions/$subId/family',
                              data: {'email': emailController.text.trim()},
                            );
                            setSheetState(() => members.add(Map<String, dynamic>.from(res.data)));
                            emailController.clear();
                            if (_user != null) _loadSubscription(_user!.id);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('✅ تم إضافة العضو'),
                                  backgroundColor: AppColors.success,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                        if (ctx.mounted) {
                          String errorMsg = 'خطأ — تأكد أن البريد الالكتروني  مسجل بالتطبيق';
                          if (e is DioException && e.response?.data != null) {
                            errorMsg = e.response!.data['message'] ?? errorMsg;
                          }
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(errorMsg),
                              backgroundColor: AppColors.error,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7B1FA2),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Icon(Icons.person_add, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'العضو يجب أن يكون مسجل بالتطبيق — أدخل بريده الالكتروني',
                  style: TextStyle(color: AppColors.textHint, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(),
          _buildSearchTab(),
          _buildSubscriptionTab(),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHomeTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => context.push('/favorites'),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).dividerColor)),
                    child: Icon(Icons.star_outline, color: AppColors.textPrimary),
                  ),
                ),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${AppLocalizations.current.tr("hello_user")} ${_user?.username ?? ""} 👋', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color), overflow: TextOverflow.ellipsis),
                  Text(AppLocalizations.current.tr('where_to_go'), style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ])),
                GestureDetector(
                  onTap: () async {
                    await context.push('/notifications');
                    if (_user != null) _loadUnreadNotifications(_user!.id);
                  },
                  child: Stack(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).dividerColor)),
                      child: Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
                    ),
                    if (_unreadNotifications > 0)
                      Positioned(top: 6, right: 6, child: Container(
                        width: 16, height: 16,
                        decoration: BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                        child: Center(child: Text(_unreadNotifications > 9 ? '9+' : '$_unreadNotifications', style: TextStyle(color: Theme.of(context).cardColor, fontSize: 9, fontWeight: FontWeight.bold))),
                      )),
                  ]),
                ),
              ],
            ),

            SizedBox(height: 24),

            GestureDetector(
              onTap: () => context.push('/search'),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: Theme.of(context).dividerColor)),
                child: Row(textDirection: TextDirection.rtl, children: [
                  Icon(Icons.search, color: AppColors.textSecondary),
                  SizedBox(width: 12),
                  Text(AppLocalizations.current.tr('search_destination'), style: TextStyle(color: AppColors.textHint, fontSize: 15)),
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.tune, color: Theme.of(context).cardColor, size: 16),
                  ),
                ]),
              ),
            ),

            SizedBox(height: 24),

            Row(textDirection: TextDirection.rtl, children: [
              _buildQuickAction(Icons.qr_code_scanner, AppLocalizations.current.tr('scan_qr'), AppColors.primary, () async {
                final result = await context.push('/qr-scanner');
                if (result == true && _user != null) {
                  setState(() => _loadingSubscription = true);
                  await _loadSubscription(_user!.id);
                }
              }),
              SizedBox(width: 12),
              _buildQuickAction(Icons.history, AppLocalizations.current.tr('my_trips'), const Color(0xFF7B1FA2), () => context.push('/trip-history')),
              SizedBox(width: 12),
              _buildQuickAction(Icons.map_outlined, AppLocalizations.current.tr('the_map'), AppColors.success, () => context.push('/map')),
            ]),
            SizedBox(height: 10),
            Row(textDirection: TextDirection.rtl, children: [
              _buildQuickAction(Icons.find_in_page_outlined, AppLocalizations.current.tr('lost_items'), AppColors.warning, () => context.push('/lost-item')),
              SizedBox(width: 12),
              _buildQuickAction(Icons.report_outlined, AppLocalizations.current.tr('report'), AppColors.error, () => context.push('/report')),
              SizedBox(width: 12),
              Expanded(child: SizedBox()),
            ]),

            SizedBox(height: 24),

            if (_recentTrips.isNotEmpty) ...[
              Text(AppLocalizations.current.tr('recent_trips'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              ..._recentTrips.map((trip) => _buildRecentTripCard(trip)),
            ],

            _buildEmptyState(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  Widget _buildRecentTripCard(String trip) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: Theme.of(context).dividerColor)),
      child: Row(textDirection: TextDirection.rtl, children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.history, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(trip, style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary), textAlign: TextAlign.right)),
        const Icon(Icons.arrow_back_ios, size: 14, color: AppColors.textSecondary),
      ]),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(children: [
        const SizedBox(height: 40),
        Icon(Icons.directions_bus_outlined, size: 80, color: AppColors.primary.withOpacity(0.3)),
        const SizedBox(height: 12),
        Text('SFRE', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary.withOpacity(0.4), letterSpacing: 4)),
      ]),
    );
  }

  Widget _buildSearchTab() {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(AppLocalizations.current.tr('search_empty'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          SizedBox(height: 16),
          GestureDetector(
            onTap: () => context.push('/search'),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: Theme.of(context).dividerColor)),
              child: Row(textDirection: TextDirection.rtl, children: [
                Icon(Icons.search, color: AppColors.textSecondary),
                SizedBox(width: 12),
                Text(AppLocalizations.current.tr('search_destination'), style: TextStyle(color: AppColors.textHint, fontSize: 15)),
              ]),
            ),
          ),
          const SizedBox(height: 40),
          Center(child: Column(children: [
            Icon(Icons.search, size: 80, color: AppColors.primary.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text('SFRE', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary.withOpacity(0.4), letterSpacing: 4)),
          ])),
        ]),
      ),
    );
  }

  Widget _buildSubscriptionTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(AppLocalizations.current.tr('my_subscription'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 20),

            if (!_loadingSubscription && _subscription == null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                margin: EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: Column(children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 40),
                  SizedBox(height: 8),
                  Text(AppLocalizations.current.tr('no_subscription'), style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  SizedBox(height: 4),
                  Text(AppLocalizations.current.tr('buy_from_pos'), style: TextStyle(color: AppColors.textSecondary, fontSize: 13), textAlign: TextAlign.center),
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/pos-map'),
                      icon: Icon(Icons.store, size: 20),
                      label: Text(AppLocalizations.current.tr('nearest_pos'), style: TextStyle(fontSize: 15)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00897B), padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                  SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        await context.push('/subscription');
                        if (_user != null) { setState(() => _loadingSubscription = true); await _loadSubscription(_user!.id); }
                      },
                      style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14)),
                      child: Text(AppLocalizations.current.tr('view_plans'), style: TextStyle(fontSize: 15)),
                    ),
                  ),
                ]),
              ),

            if (_loadingSubscription) const Center(child: CircularProgressIndicator()),

            if (!_loadingSubscription && _subscription != null) ...[
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Row(textDirection: TextDirection.rtl, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Icon(Icons.credit_card, color: Theme.of(context).cardColor, size: 32),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('اشتراك ${_subscriptionTypeAr()}', style: TextStyle(color: Theme.of(context).cardColor, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(_user?.username ?? '', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                    ]),
                  ]),
                  SizedBox(height: 20),
                  Row(textDirection: TextDirection.rtl, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(AppLocalizations.current.tr('trips_remaining'), style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                      Text('$_tripsRemaining / $_tripsLimit', style: TextStyle(color: Theme.of(context).cardColor, fontWeight: FontWeight.bold, fontSize: 18)),
                    ]),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(AppLocalizations.current.tr('expires_in'), style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                      Text(DateTime.parse(_subscription!['end_date']).toString().substring(0, 10), style: TextStyle(color: Theme.of(context).cardColor, fontWeight: FontWeight.w600)),
                    ]),
                  ]),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _tripsLimit > 0 ? _tripsUsed / _tripsLimit : 0,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(_tripsRunningLow ? const Color(0xFFFF6B6B) : Colors.white),
                      minHeight: 6,
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 20),

              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isExpiringSoon() ? AppColors.error.withOpacity(0.1) : AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _isExpiringSoon() ? AppColors.error.withOpacity(0.3) : AppColors.success.withOpacity(0.3)),
                ),
                child: Row(textDirection: TextDirection.rtl, children: [
                  Icon(Icons.timer_outlined, color: _isExpiringSoon() ? AppColors.error : AppColors.success),
                  SizedBox(width: 12),
                  Text(AppLocalizations.current.tr('sub_remaining'), style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const Spacer(),
                  Text(_timeRemaining(), style: TextStyle(color: _isExpiringSoon() ? AppColors.error : AppColors.success, fontWeight: FontWeight.bold, fontSize: 16)),
                ]),
              ),

              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _tripsRunningLow ? AppColors.error.withOpacity(0.1) : AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _tripsRunningLow ? AppColors.error.withOpacity(0.3) : AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(textDirection: TextDirection.rtl, children: [
                  Icon(Icons.confirmation_number_outlined, color: _tripsRunningLow ? AppColors.error : AppColors.primary),
                  SizedBox(width: 12),
                  Text(AppLocalizations.current.tr('trips_used_label'), style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const Spacer(),
                  Text('$_tripsUsed / $_tripsLimit', style: TextStyle(color: _tripsRunningLow ? AppColors.error : AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                ]),
              ),

              if ((_subscription!['max_users'] ?? 1) > 1) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _showFamilyDialog(),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7B1FA2).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF7B1FA2).withOpacity(0.3)),
                    ),
                    child: Row(textDirection: TextDirection.rtl, children: [
                      Icon(Icons.family_restroom, color: Color(0xFF7B1FA2)),
                      SizedBox(width: 12),
                      Expanded(child: Text(AppLocalizations.current.tr('manage_family'), style: TextStyle(color: Color(0xFF7B1FA2), fontWeight: FontWeight.w600, fontSize: 14))),
                      Text('${(_subscription!['family_members'] as List?)?.length ?? 0} / ${(_subscription!['max_users'] ?? 1) - 1}', style: const TextStyle(color: Color(0xFF7B1FA2), fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_back_ios, size: 14, color: Color(0xFF7B1FA2)),
                    ]),
                  ),
                ),
              ],

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/pos-map'),
                  icon: Icon(Icons.store, size: 20),
                  label: Text(AppLocalizations.current.tr('pos_renew'), style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00897B), padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  Widget _buildProfileTab() {
    final l = AppLocalizations.current;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(children: [
          SizedBox(height: 20),
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(22)),
            child: Center(child: Text(_user?.username.substring(0, 1).toUpperCase() ?? 'U', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold))),
          ),
          SizedBox(height: 12),
          Text(_user?.username ?? l.tr('user_default'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textPrimary)),
          Text(_user?.email ?? '', style: TextStyle(color: isDark ? Colors.white60 : AppColors.textSecondary, fontSize: 14)),
          if (_user?.phone != null && _user!.phone!.isNotEmpty)
            Text(_user!.phone!, style: TextStyle(color: isDark ? Colors.white60 : AppColors.textSecondary, fontSize: 13)),

          const SizedBox(height: 32),

          if (_subscription != null)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.primary.withOpacity(0.15) : AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(textDirection: TextDirection.rtl, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(l.tr('sub_label'), style: TextStyle(color: isDark ? Colors.white54 : AppColors.textSecondary, fontSize: 12)),
                  Text(_subscriptionTypeAr(), style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Text(l.tr('trips_label'), style: TextStyle(color: isDark ? Colors.white54 : AppColors.textSecondary, fontSize: 12)),
                  Text('\u200E$_tripsRemaining ${l.tr("trips_remaining")}', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.tr('expires_in'), style: TextStyle(color: isDark ? Colors.white54 : AppColors.textSecondary, fontSize: 12)),
                  Text(DateTime.parse(_subscription!['end_date']).toString().substring(0, 10), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ]),
              ]),
            ),

          _buildProfileItem(Icons.edit_outlined, l.tr('edit_data'), () async { await context.push('/edit-profile'); _loadUser(); }),
          _buildProfileItem(Icons.settings_outlined, l.tr('settings'), () => context.push('/settings')),
          _buildProfileItem(Icons.logout, l.tr('logout'), _logout, isLogout: true),
        ]),
      ),
    );
  }

  Widget _buildProfileItem(IconData icon, String title, VoidCallback onTap, {bool isLogout = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: Theme.of(context).dividerColor)),
        child: Row(textDirection: TextDirection.rtl, children: [
          Icon(icon, color: isLogout ? AppColors.error : AppColors.primary, size: 22),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: isLogout ? AppColors.error : (isDark ? Colors.white : AppColors.textPrimary), fontSize: 15), textAlign: TextAlign.right)),
          if (!isLogout) Icon(Icons.arrow_back_ios, size: 14, color: isDark ? Colors.white30 : AppColors.textSecondary),
        ]),
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() => _currentIndex = index);
        if (index == 2 && _user != null) { setState(() => _loadingSubscription = true); _loadSubscription(_user!.id); }
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textSecondary,
      backgroundColor: Theme.of(context).cardColor,
      elevation: 10,
      items: [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: AppLocalizations.current.tr('home')),
        BottomNavigationBarItem(icon: Icon(Icons.search_outlined), activeIcon: Icon(Icons.search), label: AppLocalizations.current.tr('search')),
        BottomNavigationBarItem(icon: Icon(Icons.card_membership_outlined), activeIcon: Icon(Icons.card_membership), label: AppLocalizations.current.tr('subscription')),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: AppLocalizations.current.tr('profile')),
      ],
    );
  }
}