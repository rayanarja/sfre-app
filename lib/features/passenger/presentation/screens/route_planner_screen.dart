import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/notification_service.dart';
import '../../data/route_suggestions_service.dart';

// ═══════════════════════════════════════════════════════
// RoutePlannerScreen — خطط رحلتك
// ═══════════════════════════════════════════════════════
class RoutePlannerScreen extends StatefulWidget {
  const RoutePlannerScreen({super.key});
  @override
  State<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends State<RoutePlannerScreen>
    with TickerProviderStateMixin {
  // ── حقول البحث
  final _controller = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _result;
  Position? _position;
  List<Map<String, dynamic>> _suggestions = [];
  Timer? _debounce;
  final RouteSuggestionsService _routeService = RouteSuggestionsService();

  // ── حالة الرحلة النشطة
  bool _isTripActive = false;
  Map<String, dynamic>? _activePlan;
  int _activeLegIndex = 0;
  StreamSubscription<Position>? _tripGpsSub;
  final List<bool> _legNotified = [];

  // ── انيميشن للكارد النشط
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _getLocation();
    NotificationService().init();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  // ══════════════════════════
  // الموقع
  // ══════════════════════════
  Future<void> _getLocation() async {
    try {
      LocationPermission p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) setState(() => _position = pos);
    } catch (_) {}
  }

  // ══════════════════════════
  // الاقتراحات
  // ══════════════════════════
  void _onTextChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (text.trim().length < 2) {
        if (mounted) setState(() => _suggestions = []);
        return;
      }
      try {
        final data = await _routeService.searchDestinations(text.trim());
        if (!mounted) return;
        setState(() => _suggestions = data);
      } catch (_) {}
    });
  }

  // ══════════════════════════
  // البحث
  // ══════════════════════════
  Future<void> _search({String? override, double? destLat, double? destLng}) async {
    final q = override ?? _controller.text.trim();
    if (q.isEmpty) return;
    if (_position == null) {
      _snack(' لم نستطع تحديد موقعك', Colors.red);
      return;
    }
    setState(() {
      _isLoading = true;
      _result = null;
      _suggestions = [];
    });
    FocusScope.of(context).unfocus();
    try {
      final suggestions = destLat != null && destLng != null
          ? await _routeService.suggestionsForCoordinates(
              userLat: _position!.latitude,
              userLng: _position!.longitude,
              destinationLat: destLat,
              destinationLng: destLng,
            )
          : await _routeService.planForText(
              destination: q,
              userLat: _position!.latitude,
              userLng: _position!.longitude,
            );
      if (mounted) {
        setState(() => _result = {
              'plans': suggestions.map((item) => item.toViewMap()).toList(),
            });
      }
    } catch (_) {
      _snack('حدث خطأ، حاول مرة ثانية', Colors.red);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _startTrip(Map<String, dynamic> plan) async {
    await _stopTrip(silent: true);

    final legs = List<Map<String, dynamic>>.from(plan['legs'] ?? []);
    if (legs.isEmpty) return;

    final waypoints = <Map<String, dynamic>>[];

    for (int i = 0; i < legs.length; i++) {
      final leg = legs[i];
      final toLat = _toDouble(leg['to_lat']);
      final toLng = _toDouble(leg['to_lng']);
      if (toLat == null || toLng == null) continue;

      String notifTitle, notifBody;
      if (leg['action'] == 'walk' && i == 0) {
        notifTitle = '🚶 اوصلت للموقف!';
        notifBody = 'ابحث عن الباص "${_cleanRoute(legs.firstWhere((l) => l['action'] == 'bus', orElse: () => {})['route_name'])}"';
      } else if (leg['action'] == 'walk' && i < legs.length - 1) {
        notifTitle = '🔄 وقت التحويل!';
        notifBody = 'انزل هنا وامشِ ${leg['meters'] ?? ''} متر للباص التاني';
      } else if (leg['action'] == 'bus') {
        final nextLegs = legs.sublist(i + 1);
        final hasTransferAfter = nextLegs.any((l) => l['action'] == 'bus');
        if (hasTransferAfter) {
          notifTitle = '⬇️ جهز نفسك للنزول!';
          notifBody = 'ستصل قريباً لنقطة التحويل في "${leg['to']}"';
        } else {
          notifTitle = '📍 وصلت لوجهتك!';
          notifBody = 'الباص اقترب من "${leg['to']}" — كن مستعدا للنزول';
        }
      } else {
        notifTitle = '🏁 وصلت!';
        notifBody = 'امشِ ${leg['meters'] ?? ''} متر لوجهتك النهائية';
      }

      waypoints.add({
        'lat': toLat,
        'lng': toLng,
        'title': notifTitle,
        'body': notifBody,
        'leg_index': i,
        'radius': leg['action'] == 'bus' ? 400.0 : 200.0,
      });
    }

    if (waypoints.isEmpty) return;

    setState(() {
      _isTripActive = true;
      _activePlan = plan;
      _activeLegIndex = 0;
      _legNotified.clear();
      _legNotified.addAll(List.filled(waypoints.length, false));
    });

    await NotificationService().showNotification(
      title: '🚌 بدأت رحلتك!',
      body: 'اتجه للموقف — سنبلغك عند كل خطوة',
    );

    int currentWaypointIdx = 0;
    _tripGpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 30,
      ),
    ).listen((Position pos) {
      if (!_isTripActive || currentWaypointIdx >= waypoints.length) return;

      final wp = waypoints[currentWaypointIdx];
      final dist = Geolocator.distanceBetween(
        pos.latitude, pos.longitude,
        wp['lat'], wp['lng'],
      );

      if (dist <= (wp['radius'] as double) && !_legNotified[currentWaypointIdx]) {
        _legNotified[currentWaypointIdx] = true;
        NotificationService().alertUser(
          title: wp['title'],
          body: wp['body'],
        );
        if (mounted) {
          setState(() => _activeLegIndex = (wp['leg_index'] as int) + 1);
        }
        currentWaypointIdx++;

        if (currentWaypointIdx >= waypoints.length) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) _stopTrip();
          });
        }
      }
    });
  }

  Future<void> _stopTrip({bool silent = false}) async {
    _tripGpsSub?.cancel();
    _tripGpsSub = null;
    NotificationService().stopTracking();
    NotificationService().stopDestinationTracking();
    if (mounted) {
      setState(() {
        _isTripActive = false;
        _activePlan = null;
        _activeLegIndex = 0;
        _legNotified.clear();
      });
    }
    if (!silent) {
      _snack('تم إيقاف الرحلة', Colors.orange);
    }
  }

  void _snack(String msg, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textDirection: TextDirection.rtl),
        backgroundColor: c,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  String _cleanRoute(String? name) =>
      name?.replaceAll(RegExp(r'[\s\-_]*(ذهاب|إياب|اياب)'), '').trim() ?? '';

  void _openMapsWalk(double? fromLat, double? fromLng, double? toLat, double? toLng) {
    if (toLat == null || toLng == null) return;
    final oLat = fromLat ?? _position?.latitude;
    final oLng = fromLng ?? _position?.longitude;
    if (oLat == null || oLng == null) return;
    final url =
        'https://www.google.com/maps/dir/?api=1&origin=$oLat,$oLng&destination=$toLat,$toLng&travelmode=walking';
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    _pulseController.dispose();
    _tripGpsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('خطّط رحلتك'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          if (_isTripActive)
            IconButton(
              icon: const Icon(Icons.stop_circle_outlined),
              tooltip: 'إيقاف الرحلة',
              onPressed: _stopTrip,
            ),
        ],
      ),
      body: Column(children: [
        if (_isTripActive && _activePlan != null) _buildActiveTripBanner(isDark),

        _buildSearchHeader(isDark),

        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _result == null
                  ? _buildEmpty()
                  : _buildResults(isDark),
        ),
      ]),
    );
  }

  Widget _buildActiveTripBanner(bool isDark) {
    final legs = List<Map<String, dynamic>>.from(_activePlan?['legs'] ?? []);
    final currentLeg = _activeLegIndex < legs.length ? legs[_activeLegIndex] : null;

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (ctx, child) => Transform.scale(scale: _pulseAnim.value, child: child),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          ),
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(19),
              ),
              child: const Icon(Icons.navigation, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text(
                  '🚌 رحلة نشطة',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  currentLeg != null
                      ? (currentLeg['action'] == 'walk'
                          ? 'امشِ نحو: ${currentLeg['to'] ?? ''}'
                          : currentLeg['action'] == 'wait'
                              ? 'انتظر الباص لمدة ${currentLeg['minutes'] ?? 0} دقائق'
                              : 'اركب خط: ${_cleanRoute(currentLeg['route_name'])} باتجاه ${currentLeg['to'] ?? ''}')
                      : '✅ وصلت لوجهتك!',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ]),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _stopTrip,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white38),
                ),
                child: const Text('إيقاف', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).cardColor,
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Row(textDirection: TextDirection.rtl, children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.my_location, color: Colors.blue, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            _position != null ? 'موقعك الحالي ✅' : 'جاري تحديد الموقع...',
            style: TextStyle(
              color: _position != null ? AppColors.success : AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(textDirection: TextDirection.rtl, children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.location_on, color: Colors.red, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              textDirection: TextDirection.rtl,
              onChanged: _onTextChanged,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'إلى أين تريد الذهاب؟',
                hintStyle: const TextStyle(fontSize: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Theme.of(context).dividerColor),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                suffixIcon: IconButton(
                  icon: Icon(Icons.search, color: AppColors.primary),
                  onPressed: () => _search(),
                ),
              ),
            ),
          ),
        ]),
        if (_suggestions.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 230),
            child: Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Theme.of(context).dividerColor),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: ListView(
                shrinkWrap: true,
                children: _suggestions.map((item) {
                  final name = item['name'] ?? '';
                  final isPlace = item['type'] == 'place';
                  final placeLat = _toDouble(item['lat']);
                  final placeLng = _toDouble(item['lng']);
                  return InkWell(
                    onTap: () {
                      _controller.text = name;
                      setState(() => _suggestions = []);
                      _search(
                        override: name,
                        destLat: placeLat,
                        destLng: placeLng,
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Theme.of(context).dividerColor.withOpacity(0.3),
                          ),
                        ),
                      ),
                      child: Row(textDirection: TextDirection.rtl, children: [
                        Icon(
                          isPlace ? Icons.place : Icons.directions_bus_outlined,
                          size: 18,
                          color: isPlace ? Colors.red : AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text(name, style: const TextStyle(fontSize: 14)),
                            if (isPlace)
                              const Text(
                                'منطقة من الخريطة',
                                style: TextStyle(fontSize: 10, color: AppColors.textHint),
                              ),
                          ]),
                        ),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.route, size: 72, color: AppColors.primary.withOpacity(0.15)),
      const SizedBox(height: 14),
      const Text(
        'ابحث عن وجهتك',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 6),
      const Text(
        'اكتب اسم المكان أو المنطقة\nوسنجد لك أفضل طريق',
        style: TextStyle(color: AppColors.textHint, fontSize: 13),
        textAlign: TextAlign.center,
      ),
    ]),
  );

  
  Widget _buildResults(bool isDark) {
    final plans = List<Map<String, dynamic>>.from(_result?['plans'] ?? []);
    final isGeocoded = _result?['geocoded'] == true;
    final geocodedPlace = _result?['geocoded_place'] ?? '';

    if (plans.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.search_off, size: 64, color: AppColors.textHint),
          const SizedBox(height: 14),
          const Text(
            'لم نجد خطوط توصلك لوجهتك',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          const Text(
            'جرّب اسم ثاني أو منطقة مجاورة',
            style: TextStyle(color: AppColors.textHint, fontSize: 13),
          ),
        ]),
      );
    }

    return Column(children: [
      if (isGeocoded)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2744) : const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Row(textDirection: TextDirection.rtl, children: [
            const Icon(Icons.place, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'بحثنا عن أقرب مسار لـ "$geocodedPlace" — الموقف قريب من وجهتك',
                style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
              ),
            ),
          ]),
        ),

      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Row(textDirection: TextDirection.rtl, children: [
          const Icon(Icons.lightbulb_outline, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            '${plans.length} اقتراح${plans.length > 1 ? 'ين' : ''} — اختر الأنسب لك',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          ),
        ]),
      ),

      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: plans.length,
          itemBuilder: (ctx, i) => _buildPlanCard(plans[i], i, isDark),
        ),
      ),
    ]);
  }

  Widget _buildPlanCard(Map<String, dynamic> plan, int index, bool isDark) {
    final isDirect = (plan['transit_type'] ?? plan['type']) == 'direct';
    final requiresWalking = plan['type'] == 'walking_required';
    final tag = plan['tag'] ?? '';
    final legs = List<Map<String, dynamic>>.from(plan['legs'] ?? []);
    final totalMin = plan['total_minutes'] ?? 0;
    final totalWalking = plan['total_walking'] ?? 0;
    final walkingTime = plan['walking_time_minutes'] ?? 0;
    final walkToStation = plan['walk_to_station'] ?? 0;
    final lastMileWalking = plan['last_mile_walking'] ?? 0;
    final transferStopName = plan['transfer_stop_name'];
    final fromLat = _toDouble(plan['from_station_lat']);
    final fromLng = _toDouble(plan['from_station_lng']);

    final isFastest = tag == 'fastest';
    final hasTag = tag == 'fastest' || tag == 'comfortable';
    final tagColor = !hasTag
        ? AppColors.primary
        : (isFastest ? const Color(0xFF1565C0) : const Color(0xFFE65100));
    final tagBg = !hasTag
        ? AppColors.primary.withOpacity(isDark ? 0.16 : 0.08)
        : isFastest
            ? (isDark ? const Color(0xFF0D2137) : const Color(0xFFE3F2FD))
            : (isDark ? const Color(0xFF2D1600) : const Color(0xFFFFF3E0));
    final tagIcon = !hasTag
        ? Icons.route
        : (isFastest ? Icons.bolt : Icons.self_improvement);
    final tagTitle = !hasTag ? 'خيار متاح' : (isFastest ? '⚡ الأسرع' : '😌 الأريح');
    final tagDesc = !hasTag
        ? 'تفاصيل الرحلة المقترحة'
        : isFastest
            ? 'أقل وقت — قد يشمل مشياً أكثر'
            : 'أقل مشي وجهد — حتى لو  كان الوقت أطول';

    final isThisActive = _isTripActive && identical(_activePlan, plan);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isThisActive
              ? AppColors.primary
              : (index == 0
                  ? AppColors.primary.withOpacity(0.4)
                  : Theme.of(context).dividerColor),
          width: isThisActive ? 2.5 : (index == 0 ? 1.5 : 1),
        ),
        boxShadow: [
          BoxShadow(
            color: (isThisActive ? AppColors.primary : Colors.black).withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: tagBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(textDirection: TextDirection.rtl, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDirect ? AppColors.primary : const Color(0xFFF57C00),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  requiresWalking
                      ? (isDirect ? '🚶 مباشرة مع مشي' : '🚶 تحويل مع مشي')
                      : (isDirect ? '🟢 رحلة مباشرة' : '🔄 رحلة بتحويل'),
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              Row(children: [
                Text(
                  '$totalMin',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: tagColor,
                  ),
                ),
                const SizedBox(width: 3),
                Text('دقيقة', style: TextStyle(fontSize: 12, color: tagColor)),
              ]),
            ]),
            const SizedBox(height: 8),
            Row(textDirection: TextDirection.rtl, children: [
              Icon(tagIcon, size: 16, color: tagColor),
              const SizedBox(width: 6),
              Text(
                tagTitle,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: tagColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tagDesc,
                  style: TextStyle(fontSize: 11, color: tagColor.withOpacity(0.8)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Row(textDirection: TextDirection.rtl, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _statChip(
                icon: Icons.directions_walk,
                label: 'مشي $totalWalking م • $walkingTime د',
                color: AppColors.textSecondary,
              ),
              _statChip(
                icon: Icons.directions_bus,
                label: '${legs.where((l) => l['action'] == 'bus').length} خط',
                color: AppColors.primary,
              ),
              if (!isDirect)
                _statChip(
                  icon: Icons.swap_horiz,
                  label: '${legs.where((l) => l['action'] == 'bus').length - 1} تحويل',
                  color: const Color(0xFFF57C00),
                ),
            ]),
          ]),
        ),

        if (requiresWalking)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.warning.withOpacity(0.35)),
            ),
            child: Text(
              '⚠️ هذه الرحلة تتطلب المشي${lastMileWalking > 0 ? '، والمشي الأخير $lastMileWalking متر' : ''}.',
              textDirection: TextDirection.rtl,
              style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600),
            ),
          ),

        if (!isDirect && transferStopName != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(textDirection: TextDirection.rtl, children: [
              const Icon(Icons.swap_horiz, color: Color(0xFFF57C00)),
              const SizedBox(width: 8),
              Expanded(child: Text('موقف التحويل: $transferStopName')),
            ]),
          ),

        if (walkToStation > 50)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(textDirection: TextDirection.rtl, children: [
              const Icon(Icons.directions_walk, size: 18, color: Color(0xFF1976D2)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'امشِ $walkToStation متر لأقرب موقف',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
              if (fromLat != null && fromLng != null)
                _navButton(
                  label: 'وجّهني',
                  onTap: () => _openMapsWalk(_position?.latitude, _position?.longitude, fromLat, fromLng),
                ),
            ]),
          ),

        const Padding(
          padding: EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Divider(height: 1),
        ),
        ...legs.asMap().entries.map((e) => _buildLeg(e.value, e.key, legs.length, isDark, isThisActive)),

        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: SizedBox(
            width: double.infinity,
            child: isThisActive
                ? OutlinedButton.icon(
                    onPressed: _stopTrip,
                    icon: const Icon(Icons.stop_circle_outlined, size: 18),
                    label: const Text('إيقاف الرحلة'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: () => _startTrip(plan),
                    icon: const Icon(Icons.navigation, size: 18),
                    label: const Text('ابدأ رحلتي 🚀', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                  ),
          ),
        ),
      ]),
    );
  }

  Widget _statChip({required IconData icon, required String label, required Color color}) {
    return Row(children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _navButton({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1976D2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.navigation, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Widget _buildLeg(
    Map<String, dynamic> leg,
    int legIdx,
    int totalLegs,
    bool isDark,
    bool isTripActive,
  ) {
    final isWalk = leg['action'] == 'walk';
    final isWaiting = leg['action'] == 'wait';
    final from = leg['from'] ?? '—';
    final to = leg['to'] ?? '—';
    final routeName = _cleanRoute(leg['route_name']);
    final minutes = leg['minutes'] ?? 0;
    final stations = leg['stations'] ?? 0;
    final meters = leg['meters'] ?? 0;
    final buses = leg['buses'] ?? 0;
    final busEta = leg['bus_eta'];
    final toLat = _toDouble(leg['to_lat']);
    final toLng = _toDouble(leg['to_lng']);
    final fromLatLeg = _toDouble(leg['from_lat']);
    final fromLngLeg = _toDouble(leg['from_lng']);

    final isActive = isTripActive && legIdx == _activeLegIndex;
    final isPast = isTripActive && legIdx < _activeLegIndex;

    final iconColor = isWaiting
        ? AppColors.warning
        : isWalk
            ? const Color(0xFF1976D2)
            : AppColors.primary;
    final iconBg = iconColor.withOpacity(0.1);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Row(textDirection: TextDirection.rtl, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: isActive
                  ? iconColor
                  : (isPast ? Colors.grey.withOpacity(0.2) : iconBg),
              borderRadius: BorderRadius.circular(10),
              border: isActive ? Border.all(color: iconColor, width: 2) : null,
            ),
            child: Icon(
              isWaiting
                  ? Icons.schedule
                  : isWalk
                      ? Icons.directions_walk
                      : Icons.directions_bus,
              color: isActive ? Colors.white : (isPast ? Colors.grey : iconColor),
              size: 20,
            ),
          ),
          if (legIdx < totalLegs - 1)
            Container(width: 2, height: 20, color: Theme.of(context).dividerColor),
        ]),
        const SizedBox(width: 12),

        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(textDirection: TextDirection.rtl, children: [
              Expanded(
                child: Text(
                  isWaiting
                      ? 'انتظر الباص'
                      : isWalk
                          ? 'تابع سيراً على الأقدام'
                          : 'اركب الباص',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isActive ? iconColor : null,
                  ),
                ),
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('▶ الآن', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              if (isPast)
                const Icon(Icons.check_circle, color: AppColors.success, size: 16),
            ]),
            const SizedBox(height: 4),

            if (!isWalk && !isWaiting) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  routeName,
                  style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'من $from ← $to',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                textDirection: TextDirection.rtl,
              ),
              Text(
                '$stations محطات • $minutes دقيقة${buses > 0 ? ' • $buses باص نشط' : ''}',
                style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                textDirection: TextDirection.rtl,
              ),
              if (busEta != null && buses > 0)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '🕐 أقرب باص بعد ~$busEta دقيقة',
                    style: const TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w500),
                  ),
                ),
              if (buses == 0)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '⚠️ لايوجد باصات نشطة حالياً على هذا هالخط',
                    style: TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w500),
                  ),
                ),
            ],

            if (isWalk) ...[
              Text(
                'من $from ← $to',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                textDirection: TextDirection.rtl,
              ),
              Text(
                '$meters متر • $minutes دقيقة مشي',
                style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                textDirection: TextDirection.rtl,
              ),
              if (toLat != null && toLng != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _navButton(
                    label: 'وجّهني',
                    onTap: () => _openMapsWalk(fromLatLeg, fromLngLeg, toLat, toLng),
                  ),
                ),
            ],
            if (isWaiting)
              Text(
                '$minutes دقيقة انتظار',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            const SizedBox(height: 4),
          ]),
        ),
      ]),
    );
  }
}
