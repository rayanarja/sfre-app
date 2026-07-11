import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/notification_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  List<String> _favorites = [];
  final NotificationService _notificationService = NotificationService();
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() => _currentPosition = pos);
    } catch (e) {
      // ignore
    }
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _favorites = prefs.getStringList('favorites') ?? []);
  }

  Future<void> _toggleFavorite(String stationName) async {
    final prefs = await SharedPreferences.getInstance();
    if (_favorites.contains(stationName)) {
      _favorites.remove(stationName);
      _showSnack('تم حذف $stationName من المفضلة', AppColors.error);
    } else {
      _favorites.add(stationName);
      _showSnack('✅ تمت إضافة $stationName للمفضلة', AppColors.success);
    }
    await prefs.setStringList('favorites', _favorites);
    setState(() {});
  }

  Future<void> _search(String query) async {
    if (query.length < 2) return;
    setState(() { _isLoading = true; _hasSearched = true; });
    try {
      final api = ApiClient();
      final params = <String, dynamic>{'destination': query};
      if (_currentPosition != null) {
        params['lat'] = _currentPosition!.latitude;
        params['lng'] = _currentPosition!.longitude;
      }
      final response = await api.dio.get('/stations/smart-search', queryParameters: params);
      setState(() {
        _results = List<Map<String, dynamic>>.from(response.data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _toggleNotification(Map<String, dynamic> route) async {
    final closest = route['closest_station'];
    if (closest == null) {
      _showSnack('لا يوجد إحداثيات لهذه المحطة', AppColors.error);
      return;
    }

    final stationName = closest['name'] as String;

    if (_notificationService.isTracking && _notificationService.targetStation?['name'] == stationName) {
      _notificationService.stopTracking();
      setState(() {});
      _showSnack('تم إلغاء التنبيه لـ $stationName', AppColors.error);
      return;
    }

    if (_notificationService.isTracking) {
      _showSnack('أنت تتابع محطة ${_notificationService.targetStation?['name']} — ألغِها أولاً', AppColors.warning);
      return;
    }

    final hasPermission = await _notificationService.requestPermission();
    if (!hasPermission) return;

    // نحتاج نجيب lat/lng للموقف الأقرب
    try {
      final api = ApiClient();
      final stationsRes = await api.dio.get('/bus-tracker/stations/${route['route_id']}');
      final stations = List<Map<String, dynamic>>.from(stationsRes.data);
      final station = stations.firstWhere((s) => s['name'] == stationName, orElse: () => {});
      if (station.isNotEmpty && station['lat'] != null && station['lng'] != null) {
        _notificationService.startTracking({
          'name': stationName,
          'lat': station['lat'],
          'lng': station['lng'],
        });
        setState(() {});
        if (mounted) _showSnack('✅ سيصلك  تنبيه عندما تقترب من $stationName', AppColors.success);
      }
    } catch (e) {
      // ignore
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('البحث عن وجهة'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // حقل البحث
          Container(
            color: Theme.of(context).cardColor,
            padding: const EdgeInsets.all(16),
            child: TextFormField(
              controller: _searchController,
              textDirection: TextDirection.rtl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'مثال: الجامعة، القلعة، المستشفى...',
                prefixIcon: _isLoading
                    ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                    : const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() { _results = []; _hasSearched = false; });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {});
                if (value.length >= 2) _search(value);
              },
            ),
          ),

          // شريط التتبع
          if (_notificationService.isTracking)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.success.withOpacity(0.1),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  const Icon(Icons.location_on, color: AppColors.success, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('جار التتبع: ${_notificationService.targetStation?['name']}',
                        style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  GestureDetector(
                    onTap: () { _notificationService.stopTracking(); setState(() {}); },
                    child: const Icon(Icons.close, color: AppColors.error, size: 18),
                  ),
                ],
              ),
            ),

          // النتائج
          Expanded(
            child: !_hasSearched
                ? _buildInitialState()
                : _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _results.isEmpty
                        ? _buildNoResults()
                        : _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 80, color: AppColors.primary.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text('ابحث عن وجهتك', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          const Text('اكتب اسم المنطقة أو الموقف', style: TextStyle(color: AppColors.textHint, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_outlined, size: 80, color: AppColors.error.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text('لا يوجد نتائج', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          const Text('حاول أن  تبحث بكلمة ثانية', style: TextStyle(color: AppColors.textHint, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildResults() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final route = _results[index];
        return _buildRouteCard(route, index == 0);
      },
    );
  }

  Widget _buildRouteCard(Map<String, dynamic> route, bool isFirst) {
    final buses = List<Map<String, dynamic>>.from(route['active_buses'] ?? []);
    final busCount = route['active_buses_count'] ?? 0;
    final bestEta = route['best_eta_minutes'];
    final closest = route['closest_station'];
    final directionAr = route['passenger_direction_ar'];
    final stationName = route['matched_station'] ?? '';
    final isFav = _favorites.contains(stationName);

    final isTrackingThis = _notificationService.isTracking && closest != null &&
        _notificationService.targetStation?['name'] == closest['name'];
    final isTrackingOther = _notificationService.isTracking && !isTrackingThis;

    return Container(
      margin: EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isFirst ? AppColors.primary : const Color(0xFFE5E7EB), width: isFirst ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // اسم الخط + badges
                Row(
                  textDirection: TextDirection.rtl,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(route['route_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary), textAlign: TextAlign.right),
                    ),
                    Row(children: [
                      GestureDetector(
                        onTap: () => _toggleFavorite(stationName),
                        child: Icon(isFav ? Icons.star : Icons.star_outline, color: isFav ? Colors.amber : AppColors.textSecondary, size: 22),
                      ),
                      const SizedBox(width: 6),
                      if (busCount > 0)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                          child: Text('$busCount باص', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      if (isFirst) ...[
                        SizedBox(width: 6),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
                          child: Text('الأفضل ⭐', style: TextStyle(color: Theme.of(context).cardColor, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ]),
                  ],
                ),

                const SizedBox(height: 10),

                // الوجهة + أقرب موقف
                Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    const Icon(Icons.flag, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text('الوجهة: $stationName', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),

                if (closest != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      const Icon(Icons.my_location, size: 14, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(
                        'أقرب موقف لك: ${closest['name']} (${(closest['distance_meters'] / 1000).toStringAsFixed(1)} كم)',
                        style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],

                if (directionAr != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Icon(directionAr == 'ذهاب' ? Icons.arrow_back : Icons.arrow_forward, size: 14, color: directionAr == 'ذهاب' ? AppColors.primary : AppColors.warning),
                      const SizedBox(width: 4),
                      Text('الاتجاه: $directionAr', style: TextStyle(color: directionAr == 'ذهاب' ? AppColors.primary : AppColors.warning, fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],

                const SizedBox(height: 4),
                Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    const Icon(Icons.stop_circle_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('${route['stations_count']} محطة', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),

          // الباصات القريبة
          if (buses.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  const Icon(Icons.directions_bus, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  const Text('الباصات القريبة:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                ],
              ),
            ),
            ...buses.take(3).map((bus) => _buildBusRow(bus, directionAr)),
            if (buses.length > 3)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Center(
                  child: Text('+${buses.length - 3} باص إضافي', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ),
              ),
          ] else ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                textDirection: TextDirection.rtl,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bus_alert, size: 16, color: AppColors.textHint),
                  const SizedBox(width: 6),
                  const Text('لا يوجد باصات نشطة حالياً', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
                ],
              ),
            ),
          ],

          // زر التنبيه
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (isTrackingOther || closest == null) ? null : () => _toggleNotification(route),
                icon: Icon(isTrackingThis ? Icons.notifications_active : Icons.notifications_outlined, size: 16),
                label: Text(
                  isTrackingThis ? 'جاري التتبع — اضغط للإلغاء' : isTrackingOther ? 'أنت تتابع محطة أخرى' : closest != null ? 'تنبيهني عند الوصول لـ ${closest['name']}' : 'تنبيهني عند الوصول',
                  style: const TextStyle(fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isTrackingThis ? AppColors.success : isTrackingOther ? Colors.grey : AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _normalizeDirection(dynamic value) {
    final text = value?.toString().trim().toLowerCase();
    if (text == null || text.isEmpty) return null;
    if (text == 'outbound' || text == 'forward' || text == 'go' || text == 'ذهاب') {
      return 'outbound';
    }
    if (text == 'inbound' || text == 'return' || text == 'back' || text == 'إياب' || text == 'اياب') {
      return 'inbound';
    }
    return null;
  }

  Widget _buildBusRow(Map<String, dynamic> bus, dynamic passengerDirection) {
    final isIdeal = bus['is_ideal'] == true;
    final minutes = bus['estimated_minutes'];
    final stationsAway = bus['stations_away'];
    final busDirection = _normalizeDirection(bus['direction'] ?? bus['direction_ar']);
    final wantedDirection = _normalizeDirection(passengerDirection);
    final sameDirection = busDirection != null && wantedDirection != null && busDirection == wantedDirection;
    final hasStationsAway = stationsAway is num;
    final isTowardPassenger = bus['is_towards_passenger'] == true ||
        isIdeal ||
        (sameDirection && (!hasStationsAway || stationsAway >= 0));
    final directionLabel = isTowardPassenger ? 'جاي باتجاهك' : 'بعكس الاتجاه';
    final directionColor = isTowardPassenger ? AppColors.success : AppColors.warning;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isIdeal ? AppColors.success.withOpacity(0.05) : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isIdeal ? AppColors.success.withOpacity(0.3) : const Color(0xFFE5E7EB)),
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            // رقم الباص
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(bus['plate_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
            ),
            const SizedBox(width: 8),

            // اتجاه
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (bus['direction'] == 'outbound' ? AppColors.primary : AppColors.warning).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(bus['direction_ar'] ?? '', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: bus['direction'] == 'outbound' ? AppColors.primary : AppColors.warning)),
            ),

            if (isIdeal) ...[
              const SizedBox(width: 4),
              const Icon(Icons.check_circle, size: 14, color: AppColors.success),
            ],

            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: directionColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isTowardPassenger ? Icons.call_received : Icons.swap_calls,
                    size: 12,
                    color: directionColor,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    directionLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: directionColor,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // المسافة والمحطات
            if (stationsAway != null)
              Text('$stationsAway محطة', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),

            const SizedBox(width: 8),

            // الوقت
            if (minutes != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: minutes <= 5 ? AppColors.success.withOpacity(0.1) : minutes <= 15 ? AppColors.warning.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$minutes د',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: minutes <= 5 ? AppColors.success : minutes <= 15 ? AppColors.warning : AppColors.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
