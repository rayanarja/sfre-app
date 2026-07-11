import '../../../../core/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:convert';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../shared/models/user_model.dart';
import 'package:flutter/foundation.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  UserModel? _user;
  Map<String, dynamic>? _driverData;
  List<Map<String, dynamic>> _shifts = [];
  Map<String, dynamic>? _currentBus;
  String? _currentRouteName;
  bool _isLoading = true;
  bool _isOnline = false;
  Timer? _locationTimer;
  Timer? _notifTimer;
  int _unreadNotifs = 0;
  int _lastNotifCount = 0;

  @override
  void initState() {
    super.initState();
    NotificationService().init();
    _loadData();
    _startNotifPolling();
  }

  void _startNotifPolling() {
    _notifTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_user != null) _checkNotifications(_user!.id);
    });
  }

  Future<void> _checkNotifications(int userId) async {
    try {
      final api = ApiClient();
      final res = await api.dio.get('/notifications/user/$userId');
      final list = List<Map<String, dynamic>>.from(res.data);
      final unread = list.where((n) => n['is_read'] == false).length;
      if (mounted) {
        if (unread > _lastNotifCount && _lastNotifCount > 0) {
          final msg = list.firstWhere((n) => n['is_read'] == false, orElse: () => {})['message'] ?? 'إشعار جديد';
          NotificationService().alertUser(title: '🔔 إشعار جديد', body: msg);
        }
        _lastNotifCount = unread;
        setState(() => _unreadNotifs = unread);
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user_data');
    final driverJson = prefs.getString('driver_data');

    if (userJson != null) {
      setState(() => _user = UserModel.fromJson(jsonDecode(userJson)));
    }

    if (driverJson != null) {
      final driver = jsonDecode(driverJson);
      setState(() {
        _driverData = driver;
        _isOnline = driver['status'] == 'online';
        _shifts = List<Map<String, dynamic>>.from(driver['shifts'] ?? []);
        if (_shifts.isNotEmpty && _shifts[0]['bus'] != null) {
          _currentBus = _shifts[0]['bus'];
        }
      });
    }

    await _fetchDriverData();
  }

  Future<void> _fetchDriverData() async {
    if (_user == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final api = ApiClient();
      final response = await api.dio.get('/drivers');
      final drivers = List<Map<String, dynamic>>.from(response.data);
      final myDriver = drivers.firstWhere(
        (d) => d['user_id'] == _user!.id || d['user']?['user_id'] == _user!.id,
        orElse: () => {},
      );

      if (myDriver.isNotEmpty) {
        final shifts = List<Map<String, dynamic>>.from(myDriver['shifts'] ?? []);
        
        // تحقق: هل في وردية نشطة؟ إذا لا → اجعله offline
        final hasActiveShift = shifts.any((s) => 
          s['status'] == 'active' || s['status'] == 'pending_stop');
        
        setState(() {
          _driverData = myDriver;
          _isOnline = myDriver['status'] == 'online' && hasActiveShift;
          _shifts = shifts;
          if (shifts.isNotEmpty && shifts[0]['bus'] != null) {
            _currentBus = shifts[0]['bus'];
          }
          _isLoading = false;
        });
        
        // إذا السيرفر يقول online بس ما في وردية نشطة → حوّلو offline
        if (myDriver['status'] == 'online' && !hasActiveShift) {
          try {
            final api = ApiClient();
            await api.dio.put('/drivers/${myDriver['driver_id']}', data: {'status': 'offline'});
          } catch (_) {}
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  /*Future<void> _sendLocation() async {
    if (_currentBus == null || !_isOnline) return;
    try {
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final api = ApiClient();
      await api.dio.put('/bus-tracker/position/${_currentBus!['bus_id']}', data: {
        'lat': position.latitude,
        'lng': position.longitude,
      });
    } catch (e) {
      // ignore
    }
  }*/    




Future<void> _sendLocation() async {
  debugPrint('[_sendLocation] Called');

  if (_currentBus == null) {
    debugPrint('[_sendLocation] _currentBus is null');
    return;
  }

  if (!_isOnline) {
    debugPrint('[_sendLocation] Device is offline');
    return;
  }

  try {
    debugPrint('[_sendLocation] Getting current position...');

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    debugPrint(
      '[_sendLocation] Position: '
      'lat=${position.latitude}, lng=${position.longitude}',
    );

    final busId = _currentBus!['bus_id'];
    debugPrint('[_sendLocation] Bus ID: $busId');

    final api = ApiClient();
    final endpoint = '/bus-tracker/position/$busId';

    debugPrint('[_sendLocation] PUT $endpoint');
    debugPrint(
      '[_sendLocation] Payload: '
      '{lat: ${position.latitude}, lng: ${position.longitude}}',
    );

    final response = await api.dio.put(
      endpoint,
      data: {
        'lat': position.latitude,
        'lng': position.longitude,
      },
    );

    debugPrint(
      '[_sendLocation] Success '
      'status=${response.statusCode} '
      'data=${response.data}',
    );
  } catch (e, stackTrace) {
    debugPrint('[_sendLocation] ERROR: $e');
    debugPrint('[_sendLocation] STACK TRACE:\n$stackTrace');
  }
}

  void _startLocationTracking() {
    _sendLocation();
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _sendLocation();
    });
  }

  void _stopLocationTracking() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  Future<void> _toggleOnline() async {
    if (_driverData == null) return;

    // بدء العمل
    if (!_isOnline) {
      if (_currentBus == null) {
        _showSnack(AppLocalizations.current.tr('no_shift_assigned'), AppColors.warning);
        return;
      }
      await _startWork();
      return;
    }

    // إيقاف العمل — نظام التأكيد الاحترافي
    await _showStopConfirmation();
  }

  Future<void> _startWork() async {
    try {
      final api = ApiClient();
      
      // تحقق من حالة الباص — إذا بالصيانة أو عطلان ما بيقدر يبلّش
      if (_currentBus != null) {
        final busRes = await api.dio.get('/buses/${_currentBus!['bus_id']}');
        final freshBus = busRes.data;
        final busStatus = freshBus['current_status'];
        
        if (busStatus == 'maintenance') {
          _showSnack('⚠️ الباص  في الصيانة — تواصل مع الإدارة', AppColors.warning);
          return;
        }
        if (busStatus == 'breakdown') {
          _showSnack('⚠️ الباص معطّل — تواصل مع الإدارة', AppColors.warning);
          return;
        }
      }
      
      await api.dio.put('/drivers/${_driverData!['driver_id']}', data: {'status': 'online'});
      if (_currentBus != null) {
        await api.dio.put('/buses/${_currentBus!['bus_id']}', data: {'current_status': 'active'});
        await api.dio.post('/driver-actions/log-activity', data: {
          'driver_id': _driverData!['driver_id'],
          'bus_id': _currentBus!['bus_id'],
          'action': 'start',
        });
      }
      setState(() => _isOnline = true);
      _startLocationTracking();
      _showSnack('✅ أنت متصل — الباص ${_currentBus?['plate_number'] ?? ''} نشط', AppColors.success);
      await _fetchDriverData();
    } catch (e) {
      _showSnack(AppLocalizations.current.tr('error'), AppColors.error);
    }
  }

  /// نظام التأكيد — BottomSheet مع عداد تنازلي 30 ثانية
  Future<void> _showStopConfirmation() async {
    // أولاً: أرسل طلب الإيقاف المؤقت للسيرفر
    try {
      final api = ApiClient();
      final response = await api.dio.post('/driver-actions/log-activity', data: {
        'driver_id': _driverData!['driver_id'],
        'bus_id': _currentBus!['bus_id'],
        'action': 'stop',
      });

      final isPending = response.data['pending'] == true;
      if (!isPending) return;
    } catch (e) {
      _showSnack(AppLocalizations.current.tr('error'), AppColors.error);
      return;
    }

    if (!mounted) return;

    // اعرض BottomSheet التأكيد
    final result = await showModalBottomSheet<String>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _StopConfirmationSheet(),
    );

    final api = ApiClient();
    if (result == 'confirm') {
      // تأكيد الإيقاف
      try {
        await api.dio.post('/driver-actions/confirm-stop', data: {
          'driver_id': _driverData!['driver_id'],
          'bus_id': _currentBus!['bus_id'],
        });
        await api.dio.put('/drivers/${_driverData!['driver_id']}', data: {'status': 'offline'});
        if (_currentBus != null) {
          await api.dio.put('/buses/${_currentBus!['bus_id']}', data: {'current_status': 'inactive'});
        }
        setState(() => _isOnline = false);
        _stopLocationTracking();
        _showSnack('⛔ تم إنهاء الدوام', AppColors.error);
        await _fetchDriverData();
      } catch (e) {
        _showSnack(AppLocalizations.current.tr('error'), AppColors.error);
      }
    } else {
      // تراجع (إلغاء أو انتهى الوقت)
      try {
        await api.dio.post('/driver-actions/cancel-stop', data: {
          'driver_id': _driverData!['driver_id'],
          'bus_id': _currentBus!['bus_id'],
        });
        _showSnack('✅ تم التراجع — أنت لازلت بالدوام', AppColors.success);
      } catch (e) {
        _showSnack(AppLocalizations.current.tr('error_undo'), AppColors.error);
      }
    }
  }

  // === إبلاغ عن تأخير ===
  // === إبلاغ عن عطل ===
  Future<void> _showBreakdownDialog() async {
    final descController = TextEditingController();
    final breakdownTypes = ['مشكلة بالمحرك', 'إطار مثقوب', 'مشكلة كهربائية', 'مشكلة بالفرامل', 'أخرى'];
    String selectedType = breakdownTypes[0];

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            textDirection: TextDirection.rtl,
            children: [Icon(Icons.build, color: AppColors.error), SizedBox(width: 8), Text(AppLocalizations.current.tr('report_breakdown'))],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(AppLocalizations.current.tr('breakdown_type'), style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...breakdownTypes.map((t) => RadioListTile<String>(
                title: Text(t, style: const TextStyle(fontSize: 14)),
                value: t,
                groupValue: selectedType,
                onChanged: (v) => setDialogState(() => selectedType = v!),
                dense: true,
                contentPadding: EdgeInsets.zero,
              )),
              SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: InputDecoration(labelText: 'تفاصيل إضافية (اختياري)', prefixIcon: Icon(Icons.description_outlined)),
                textAlign: TextAlign.right,
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.current.tr('cancel'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppLocalizations.current.tr('report_btn')),
            ),
          ],
        ),
      ),
    );

    if (result == true && _currentBus != null) {
      try {
        final api = ApiClient();
        await api.dio.post('/driver-actions/report-breakdown', data: {
          'driver_id': _driverData!['driver_id'],
          'bus_id': _currentBus!['bus_id'],
          'description': '$selectedType${descController.text.isNotEmpty ? ' — ${descController.text}' : ''}',
          'station_name': null,
        });
        _showSnack('✅ تم الإبلاغ عن العطل', AppColors.success);
      } catch (e) {
        _showSnack(AppLocalizations.current.tr('error'), AppColors.error);
      }
    }
  }

  // === طلب باص إضافي ===
  Future<void> _showExtraBusDialog() async {
    final noteController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          textDirection: TextDirection.rtl,
          children: [Icon(Icons.add_circle_outline, color: AppColors.primary), SizedBox(width: 8), Text(AppLocalizations.current.tr('request_extra_bus'))],
        ),
        content: TextField(controller: noteController, decoration: InputDecoration(labelText: AppLocalizations.current.tr('note_optional'), prefixIcon: Icon(Icons.note_outlined)), textAlign: TextAlign.right),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.current.tr('cancel'))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppLocalizations.current.tr('send_request'))),
        ],
      ),
    );

    if (result == true && _currentBus != null) {
      try {
        final api = ApiClient();
        await api.dio.post('/driver-actions/request-bus', data: {
          'driver_id': _driverData!['driver_id'],
          'bus_id': _currentBus!['bus_id'],
          'route_name': _currentRouteName,
          'note': noteController.text.isNotEmpty ? noteController.text : null,
        });
        _showSnack('✅ تم إرسال الطلب للإدارة ' , AppColors.success);
      } catch (e) {
        _showSnack(AppLocalizations.current.tr('error'), AppColors.error);
      }
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _logout() async {
    if (_isOnline && _driverData != null) {
      try {
        final api = ApiClient();
        await api.dio.put('/drivers/${_driverData!['driver_id']}', data: {'status': 'offline'});
        if (_currentBus != null) {
          await api.dio.put('/buses/${_currentBus!['bus_id']}', data: {'current_status': 'inactive'});
          // logDriverActivity بتحط الوردية paused
          await api.dio.post('/driver-actions/log-activity', data: {
            'driver_id': _driverData!['driver_id'],
            'bus_id': _currentBus!['bus_id'],
            'action': 'stop',
          });
        }
      } catch (e) {}
    }
    _stopLocationTracking();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: _fetchDriverData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(onPressed: _logout, icon: Icon(Icons.logout, color: AppColors.error)),
                          IconButton(onPressed: () => context.push('/settings'), icon: Icon(Icons.settings_outlined, color: AppColors.textSecondary)),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text('أهلاً، ${_user?.username ?? AppLocalizations.current.tr('driver_default')} 👋', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            Text(_user?.phone ?? '', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          ]),
                          Container(
                            width: 50, height: 50,
                            decoration: BoxDecoration(color: AppColors.driverColor, borderRadius: BorderRadius.circular(14)),
                            child: Center(child: Text(_user?.username.substring(0, 1).toUpperCase() ?? 'S', style: TextStyle(color: Theme.of(context).cardColor, fontSize: 22, fontWeight: FontWeight.bold))),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // حالة الاتصال
                      GestureDetector(
                        onTap: _toggleOnline,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _isOnline ? [const Color(0xFF388E3C), const Color(0xFF2E7D32)] : [const Color(0xFF757575), const Color(0xFF616161)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            textDirection: TextDirection.rtl,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text(_isOnline ? AppLocalizations.current.tr('online') : AppLocalizations.current.tr('offline'), style: TextStyle(color: Theme.of(context).cardColor, fontSize: 22, fontWeight: FontWeight.bold)),
                                SizedBox(height: 4),
                                Text(_isOnline ? AppLocalizations.current.tr('tap_to_stop') : AppLocalizations.current.tr('tap_to_start'), style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                              ]),
                              Container(
                                width: 60, height: 60,
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                                child: Icon(_isOnline ? Icons.power_settings_new : Icons.play_arrow_rounded, color: Theme.of(context).cardColor, size: 32),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 20),

                      // معلومات الباص
                      if (_currentBus != null)
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: Theme.of(context).dividerColor)),
                          child: Row(textDirection: TextDirection.rtl, children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                              child: Icon(Icons.directions_bus, color: AppColors.primary),
                            ),
                            SizedBox(width: 12),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text(AppLocalizations.current.tr('bus_label'), style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              Text(_currentBus!['plate_number'] ?? '—', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ]),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _currentBus!['current_status'] == 'active' ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _currentBus!['current_status'] == 'active' ? 'نشط' : _currentBus!['current_status'] == 'breakdown' ? 'عطل' : 'متوقف',
                                style: TextStyle(color: _currentBus!['current_status'] == 'active' ? AppColors.success : AppColors.error, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ]),
                        ),

                      const SizedBox(height: 20),

                      // أزرار الإجراءات
                      const Text('📋 إجراءات سريعة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 12),

                      Row(textDirection: TextDirection.rtl, children: [
                        _buildAction(Icons.build, 'عطل', AppColors.error, _currentBus != null ? _showBreakdownDialog : null),
                        SizedBox(width: 10),
                        _buildAction(Icons.add_circle_outline, 'باص إضافي', AppColors.primary, _currentBus != null ? _showExtraBusDialog : null),
                      ]),

                      SizedBox(height: 8),

                      Row(textDirection: TextDirection.rtl, children: [
                        _buildAction(Icons.find_in_page_outlined, AppLocalizations.current.tr('lost_items'), const Color(0xFF8E24AA), () => context.push('/lost-item')),
                        SizedBox(width: 10),
                        _buildAction(Icons.notifications_outlined, '${AppLocalizations.current.tr("notifications")}${_unreadNotifs > 0 ? ' ($_unreadNotifs)' : ''}', const Color(0xFFE65100), () { _lastNotifCount = _unreadNotifs; context.push('/notifications'); }),
                        const SizedBox(width: 10),
                        const Expanded(child: SizedBox()),
                      ]),

                      SizedBox(height: 24),

                      // ورديات
                      Text('🗓️ ورديّاتي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      SizedBox(height: 12),

                      if (_shifts.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(24),
                          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: Theme.of(context).dividerColor)),
                          child: Column(children: [
                            Icon(Icons.event_busy_outlined, size: 48, color: AppColors.textHint.withOpacity(0.5)),
                            SizedBox(height: 8),
                            Text(AppLocalizations.current.tr('no_shifts'), style: TextStyle(color: AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            Text('Admin assigns shifts from dashboard', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
                          ]),
                        )
                      else
                        ..._shifts.map((s) => _buildShiftCard(s)),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildAction(IconData icon, String label, Color color, VoidCallback? onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: onTap != null ? 1.0 : 0.4,
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
      ),
    );
  }

  Widget _buildShiftCard(Map<String, dynamic> shift) {
    final status = shift['status'] ?? '';
    final isActive = status == 'active';
    final isPaused = status == 'paused';
    final busPlate = shift['bus']?['plate_number'] ?? '—';

    Color statusColor = AppColors.primary;
    String statusText = '';
    if (isActive) { statusColor = AppColors.success; statusText = 'نشطة'; }
    else if (isPaused) { statusColor = AppColors.warning; statusText = 'متوقف مؤقتاً'; }
    else if (status == 'completed') { statusText = 'منتهية'; }
    else if (status == 'scheduled') { statusColor = AppColors.primary; statusText = 'مجدولة'; }

    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isActive ? AppColors.success.withOpacity(0.5) : isPaused ? AppColors.warning.withOpacity(0.5) : const Color(0xFFE5E7EB)),
      ),
      child: Row(textDirection: TextDirection.rtl, children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.directions_bus, color: statusColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(textDirection: TextDirection.rtl, children: [
              Text(shift['shift_type'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(width: 8),
              if (statusText.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: statusColor.withOpacity(isActive || isPaused ? 1 : 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(statusText, style: TextStyle(color: isActive || isPaused ? Colors.white : statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ]),
            const SizedBox(height: 4),
            Text('🚌 $busPlate  •  ${shift['start_time']} — ${shift['end_time']}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ]),
        ),
      ]),
    );
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _notifTimer?.cancel();
    super.dispose();
  }
}

/// BottomSheet تأكيد الإيقاف مع عداد تنازلي
class _StopConfirmationSheet extends StatefulWidget {
  @override
  State<_StopConfirmationSheet> createState() => _StopConfirmationSheetState();
}

class _StopConfirmationSheetState extends State<_StopConfirmationSheet> {
  int _secondsLeft = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        if (mounted) Navigator.pop(context, 'cancel'); // انتهى الوقت = تراجع تلقائي
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _secondsLeft / 30;

    return WillPopScope(
      onWillPop: () async => false, // منع الإغلاق بالسحب
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),

            // أيقونة تحذير
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 40),
            ),
            const SizedBox(height: 16),

            const Text(
              'إنهاء الدوام',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 8),

            Text(
              'هل أنت متأكد من إنهاء دوامك؟',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 20),

            // العداد التنازلي
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 64, height: 64,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 4,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _secondsLeft <= 10 ? AppColors.error : AppColors.warning,
                    ),
                  ),
                ),
                Text(
                  '$_secondsLeft',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _secondsLeft <= 10 ? AppColors.error : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'ثانية للتراجع',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 24),

            // أزرار
            Row(
              textDirection: TextDirection.rtl,
              children: [
                // زر التراجع (الأكبر — الخيار الآمن)
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, 'cancel'),
                    icon: Icon(Icons.undo, size: 18),
                    label: Text(AppLocalizations.current.tr('undo_stop'), style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // زر التأكيد (أصغر)
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, 'confirm'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(AppLocalizations.current.tr('confirm_stop'), style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
