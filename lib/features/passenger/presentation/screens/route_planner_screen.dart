import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/l10n/app_localizations.dart';

class RoutePlannerScreen extends StatefulWidget {
  const RoutePlannerScreen({super.key});
  @override
  State<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends State<RoutePlannerScreen> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _result;
  Position? _position;
  List<Map<String, dynamic>> _suggestions = [];
  Timer? _debounce;

  @override
  void initState() { super.initState(); _getLocation(); }

  Future<void> _getLocation() async {
    try {
      LocationPermission p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.deniedForever) return;
      _position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {});
    } catch (_) {}
  }

  void _onTextChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (text.trim().length < 2) { setState(() => _suggestions = []); return; }
      try {
        final api = ApiClient();
        final res = await api.dio.get('/stations/hybrid-suggestions', queryParameters: {'q': text.trim()});
        final data = res.data;
        if (data is List) {
          setState(() {
            _suggestions = data.map<Map<String, dynamic>>((item) {
              if (item is String) return {'name': item, 'type': 'station'};
              return Map<String, dynamic>.from(item);
            }).toList();
          });
        }
      } catch (_) {}
    });
  }

  Future<void> _search({String? override, double? destLat, double? destLng}) async {
    final q = override ?? _controller.text.trim();
    if (q.isEmpty) return;
    if (_position == null) { _snack(AppLocalizations.current.tr('cant_detect_location'), Colors.red); return; }
    setState(() { _isLoading = true; _result = null; _suggestions = []; });
    FocusScope.of(context).unfocus();
    try {
      final api = ApiClient();
      final params = <String, dynamic>{
        'destination': q,
        'lat': _position!.latitude,
        'lng': _position!.longitude,
      };
      // إذا عندنا إحداثيات (بحث بمنطقة) — أرسلها
      if (destLat != null && destLng != null) {
        params['dest_lat'] = destLat;
        params['dest_lng'] = destLng;
      }
      final res = await api.dio.get('/stations/plan-route-v2', queryParameters: params);
      setState(() => _result = Map<String, dynamic>.from(res.data));
    } catch (_) { _snack(AppLocalizations.current.tr('error'), Colors.red); }
    setState(() => _isLoading = false);
  }

  void _snack(String msg, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: c, behavior: SnackBarBehavior.floating));
  }

  String _cleanRoute(String? name) => name?.replaceAll(RegExp(r'[\s\-_]*(ذهاب|إياب|اياب)'), '').trim() ?? '';

  // فتح Google Maps للمشي
  void _openWalkingDirections(double? toLat, double? toLng) {
    if (toLat == null || toLng == null || _position == null) return;
    final url = 'https://www.google.com/maps/dir/?api=1&origin=${_position!.latitude},${_position!.longitude}&destination=$toLat,$toLng&travelmode=walking';
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() { _controller.dispose(); _debounce?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.current;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(l.tr('search_title')), backgroundColor: AppColors.primary, foregroundColor: Colors.white, centerTitle: true),
      body: Column(children: [
        Container(
          padding: EdgeInsets.all(16), color: Theme.of(context).cardColor,
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(textDirection: TextDirection.rtl, children: [
              Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.my_location, color: Colors.blue, size: 18)),
              const SizedBox(width: 10),
              Text(_position != null ? '${l.tr("your_location")} ✅' : l.tr('detecting_location'),
                style: TextStyle(color: _position != null ? AppColors.success : AppColors.textSecondary, fontSize: 13)),
            ]),
            SizedBox(height: 12),
            Row(textDirection: TextDirection.rtl, children: [
              Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.location_on, color: Colors.red, size: 18)),
              SizedBox(width: 10),
              Expanded(child: TextField(
                controller: _controller, textDirection: TextDirection.rtl,
                onChanged: _onTextChanged, onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: l.tr('search_hint'), hintStyle: TextStyle(fontSize: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).dividerColor)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  suffixIcon: IconButton(icon: Icon(Icons.search, color: AppColors.primary), onPressed: () => _search()),
                ),
              )),
            ]),
            // اقتراحات (محطات + أماكن)
            if (_suggestions.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: Container(
                  margin: EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Theme.of(context).dividerColor)),
                  child: ListView(
                    shrinkWrap: true,
                    children: _suggestions.map((item) {
                      final name = item['name'] ?? '';
                      final isPlace = item['type'] == 'place';
                      final placeLat = item['lat'];
                      final placeLng = item['lng'];
                      return InkWell(
                  onTap: () {
                    _controller.text = name;
                    setState(() => _suggestions = []);
                    if (isPlace && placeLat != null && placeLng != null) {
                      _search(override: name, destLat: (placeLat is int ? placeLat.toDouble() : placeLat), destLng: (placeLng is int ? placeLng.toDouble() : placeLng));
                    } else {
                      _search(override: name);
                    }
                  },
                  child: Container(width: double.infinity, padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.3)))),
                    child: Row(textDirection: TextDirection.rtl, children: [
                      Icon(isPlace ? Icons.place : Icons.directions_bus_outlined, size: 18,
                        color: isPlace ? Colors.red : AppColors.primary),
                      SizedBox(width: 8),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(name, style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyLarge?.color)),
                        if (isPlace) Text('منطقة من الخريطة', style: TextStyle(fontSize: 10, color: AppColors.textHint)),
                      ])),
                    ])),
                ); }).toList()),
              ),
              ),
          ]),
        ),
        Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator())
          : _result == null ? _buildEmpty(l) : _buildResults(l, isDark)),
      ]),
    );
  }

  Widget _buildEmpty(AppLocalizations l) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.search, size: 70, color: AppColors.primary.withOpacity(0.2)),
    const SizedBox(height: 12),
    Text(l.tr('search_empty'), style: const TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w500)),
    const SizedBox(height: 4),
    Text(l.tr('search_empty_desc'), style: const TextStyle(color: AppColors.textHint, fontSize: 13), textAlign: TextAlign.center),
  ]));

  Widget _buildResults(AppLocalizations l, bool isDark) {
    final plans = List<Map<String, dynamic>>.from(_result?['plans'] ?? []);
    final isGeocoded = _result?['geocoded'] == true;
    final geocodedPlace = _result?['geocoded_place'] ?? '';
    
    if (plans.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.search_off, size: 60, color: AppColors.textHint),
      const SizedBox(height: 12), Text(l.tr('no_routes_found'), style: const TextStyle(color: AppColors.textSecondary, fontSize: 15)),
      const SizedBox(height: 4), Text(l.tr('try_another'), style: const TextStyle(color: AppColors.textHint, fontSize: 13)),
    ]));
    return Column(children: [
      // بانر يوضح إنو البحث كان بمنطقة مو محطة
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
            Expanded(child: Text('أقرب مسارات لـ "$geocodedPlace" — انزل بالمحطة وامشي للوجهة',
              style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500))),
          ]),
        ),
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.all(16), itemCount: plans.length,
        itemBuilder: (c, i) => _buildPlanCard(plans[i], i, l, isDark),
      )),
    ]);
  }

  Widget _buildPlanCard(Map<String, dynamic> plan, int index, AppLocalizations l, bool isDark) {
    final isDirect = plan['type'] == 'direct';
    final legs = List<Map<String, dynamic>>.from(plan['legs'] ?? []);
    final totalMin = plan['total_minutes'] ?? 0;
    final walkDist = plan['walk_to_station'] ?? 0;
    final fromLat = plan['from_station_lat'];
    final fromLng = plan['from_station_lng'];
    final tag = plan['tag'] ?? '';
    final tagAr = plan['tag_ar'] ?? '';

    // لون الوسم حسب النوع
    Color tagColor = AppColors.success;
    if (tag == 'fastest') tagColor = const Color(0xFF1976D2);
    else if (tag == 'comfort') tagColor = const Color(0xFFFA8C16);
    else if (tag == 'alternative') tagColor = AppColors.textSecondary;

    return Container(
      margin: EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: index == 0 ? AppColors.primary.withOpacity(0.5) : Theme.of(context).dividerColor, width: index == 0 ? 2 : 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: isDirect ? AppColors.primary.withOpacity(isDark ? 0.15 : 0.05) : (isDark ? const Color(0xFF3D2E00) : const Color(0xFFFFF7E6)),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15))),
          child: Row(textDirection: TextDirection.rtl, children: [
            Container(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: isDirect ? AppColors.primary : const Color(0xFFFA8C16), borderRadius: BorderRadius.circular(20)),
              child: Text(isDirect ? l.tr('direct_trip') : (plan['type_ar'] ?? l.tr('transfer_trip')), style: TextStyle(color: Theme.of(context).cardColor, fontSize: 12, fontWeight: FontWeight.bold))),
            const Spacer(),
            if (tagAr.isNotEmpty) Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: tagColor, borderRadius: BorderRadius.circular(10)),
              child: Text(tagAr, style: TextStyle(color: Theme.of(context).cardColor, fontSize: 10, fontWeight: FontWeight.bold))),
            const SizedBox(width: 8),
            Text('$totalMin ${l.tr("minutes")}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(width: 4), const Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
          ]),
        ),

        // المشي مع زر "وجّهني"
        if (walkDist > 50) Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(textDirection: TextDirection.rtl, children: [
            const Icon(Icons.directions_walk, size: 18, color: Color(0xFF1976D2)),
            const SizedBox(width: 8),
            Expanded(child: Text('${l.tr("walk_to_stop").replaceAll("{m}", walkDist.toString())}',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary))),
            if (fromLat != null && fromLng != null)
              GestureDetector(
                onTap: () => _openWalkingDirections(fromLat is int ? (fromLat as int).toDouble() : fromLat, fromLng is int ? (fromLng as int).toDouble() : fromLng),
                child: Container(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF1976D2), borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.navigation, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text(AppLocalizations.current.tr('guide_me'), style: TextStyle(color: Theme.of(context).cardColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  ])),
              ),
          ]),
        ),

        ...legs.map((leg) => _buildLeg(leg, l)),
        const SizedBox(height: 12),
      ]),
    );
  }

  Widget _buildLeg(Map<String, dynamic> leg, AppLocalizations l) {
    final isWalk = leg['action'] == 'walk';
    final from = leg['from'] ?? '—';
    final to = leg['to'] ?? '—';
    final routeName = _cleanRoute(leg['route_name']);
    final minutes = leg['minutes'] ?? 0;
    final stations = leg['stations'] ?? 0;
    final meters = leg['meters'] ?? 0;
    final buses = leg['buses'] ?? 0;
    final busEta = leg['bus_eta'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(textDirection: TextDirection.rtl, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(color: (isWalk ? const Color(0xFF1976D2) : AppColors.primary).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(isWalk ? Icons.directions_walk : Icons.directions_bus, color: isWalk ? const Color(0xFF1976D2) : AppColors.primary, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(isWalk ? l.tr('walk_to_transfer') : l.tr('ride_bus'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          if (!isWalk) ...[
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(routeName, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600))),
            const SizedBox(height: 4),
            Text('${l.tr("from_to").replaceAll("{f}", from).replaceAll("{t}", to)}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            Text('${l.tr("stations_minutes").replaceAll("{s}", "$stations").replaceAll("{m}", "$minutes")}${buses > 0 ? ' \u2022 ${l.tr("active_buses").replaceAll("{n}", "$buses")}' : ''}',
              style: const TextStyle(fontSize: 11, color: AppColors.textHint), textDirection: TextDirection.rtl),
            if (busEta != null && buses > 0)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('🕐 أقرب باص بعد ~$busEta ${l.tr("minutes")}',
                  style: const TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w500)),
              ),
            if (buses == 0)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Text('⚠️ ما في باصات نشطة حالياً على هالخط',
                  style: TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w500)),
              ),
          ],
          if (isWalk) ...[
            Text('${l.tr("from_to").replaceAll("{f}", from).replaceAll("{t}", to)}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            Text('${l.tr("walk_meters_min").replaceAll("{m}", "$meters").replaceAll("{n}", "$minutes")}', style: const TextStyle(fontSize: 11, color: AppColors.textHint), textDirection: TextDirection.rtl),
            // زر وجّهني للمشي
            if (leg['to_lat'] != null && leg['to_lng'] != null)
              GestureDetector(
                onTap: () {
                  final fromLat = leg['from_lat'];
                  final fromLng = leg['from_lng'];
                  final toLat = leg['to_lat'];
                  final toLng = leg['to_lng'];
                  if (toLat != null && toLng != null) {
                    final originLat = fromLat ?? _position?.latitude;
                    final originLng = fromLng ?? _position?.longitude;
                    if (originLat != null && originLng != null) {
                      final url = 'https://www.google.com/maps/dir/?api=1&origin=$originLat,$originLng&destination=$toLat,$toLng&travelmode=walking';
                      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                    }
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF1976D2), borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.navigation, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(l.tr('guide_me'), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
          ],
        ])),
      ]),
    );
  }
}