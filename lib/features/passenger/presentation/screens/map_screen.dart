import 'dart:async';

import '../../../../core/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/notification_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  List<Map<String, dynamic>> _stations = [];
  List<Map<String, dynamic>> _buses = [];
  Timer? _busPollingTimer;
  bool _isLoading = true;
  bool _isDarkMap = false;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadData();
    _busPollingTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadActiveBuses(),
    );
  }

  @override
  void dispose() {
    _busPollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _getCurrentLocation();
    await _loadStations();
    await _loadActiveBuses();
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.deniedForever) {
        setState(() => _currentPosition = const LatLng(36.2021, 37.1343));
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() =>
          _currentPosition = LatLng(position.latitude, position.longitude));
    } catch (e) {
      setState(() => _currentPosition = const LatLng(36.2021, 37.1343));
    }
  }

  Future<void> _loadStations() async {
    try {
      final api = ApiClient();
      final response = await api.dio.get('/stations');
      if (!mounted) return;
      setState(() {
        _stations = List<Map<String, dynamic>>.from(response.data)
            .where((s) => s['lat'] != null && s['lng'] != null)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadActiveBuses() async {
    try {
      final api = ApiClient();
      final response = await api.dio.get('/bus-tracker/map');
      final data = response.data;
      final rawBuses = data is Map ? data['buses'] : data;
      if (rawBuses is! List) return;

      final buses = rawBuses
          .whereType<Map>()
          .map((bus) => Map<String, dynamic>.from(bus))
          .where((bus) =>
              _toDouble(bus['lat']) != null &&
              _toDouble(bus['lng']) != null &&
              (bus['status'] == null || bus['status'] == 'active'))
          .toList();

      if (!mounted) return;
      setState(() => _buses = buses);
    } catch (_) {
      // Keep the latest visible bus positions if a polling request fails.
    }
  }

  static double? _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String _formatBusValue(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return '-';
    return value.toString();
  }

  String _formatDirection(dynamic value) {
    final text = value?.toString().trim().toLowerCase();
    if (text == 'outbound' || text == 'forward' || text == 'go' || text == 'ذهاب') {
      return 'ذهاب';
    }
    if (text == 'inbound' || text == 'return' || text == 'back' || text == 'إياب' || text == 'اياب') {
      return 'إياب';
    }
    return _formatBusValue(value);
  }

  void _showBusPopup(Map<String, dynamic> bus) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              textDirection: TextDirection.rtl,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.directions_bus_filled,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'باص ${_formatBusValue(bus['plate_number'])}',
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        _formatBusValue(bus['route_name']),
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _busInfoRow('رقم الباص', bus['bus_id']),
            _busInfoRow('الحالة', bus['status']),
            _busInfoRow('الاتجاه', _formatDirection(bus['direction'] ?? bus['direction_ar'])),
            _busInfoRow('ترتيب المحطة الحالية', bus['current_station_index']),
            _busInfoRow('رقم الخط', bus['route_id']),
            _busInfoRow('آخر تحديث', bus['last_update']),
          ],
        ),
      ),
    );
  }

  Widget _busInfoRow(String label, dynamic value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _formatBusValue(value),
              textAlign: TextAlign.left,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showStationPopup(Map<String, dynamic> station) {
    final isTracking = _notificationService.isTracking &&
        _notificationService.targetStation?['name'] == station['name'];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              textDirection: TextDirection.rtl,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      const Icon(Icons.location_on, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        station['name'] ?? '—',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (station['route'] != null)
                        Text(
                          'خط: ${station['route']['route_name']}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  if (isTracking) {
                    _notificationService.stopTracking();
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '${AppLocalizations.current.tr("alert_cancelled")} - ${station["name"]}'),
                        backgroundColor: AppColors.error,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } else {
                    if (_notificationService.isTracking) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'أنت تتابع ${_notificationService.targetStation?['name']} — ألغِها أولاً',
                          ),
                          backgroundColor: AppColors.warning,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    final hasPermission =
                        await _notificationService.requestPermission();
                    if (!hasPermission) return;
                    _notificationService.startTracking({
                      'name': station['name'],
                      'lat': station['lat'],
                      'lng': station['lng'],
                    });
                    setState(() {});
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '✅  سيصلك تنبيه عندما تقترب من ${station['name']}'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                icon: Icon(
                  isTracking
                      ? Icons.notifications_off_outlined
                      : Icons.notifications_outlined,
                  size: 18,
                ),
                label: Text(
                  isTracking
                      ? AppLocalizations.current.tr('cancel_tracking')
                      : AppLocalizations.current.tr('track_stop'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isTracking ? AppColors.error : AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            // ═══ زر تتبع الوجهة (موقع الباص) ═══
            const SizedBox(height: 8),
            if (station['lat'] != null && station['lng'] != null)
              SizedBox(
                width: double.infinity,
                child: Builder(builder: (ctx) {
                  final isDestTracking =
                      _notificationService.isTrackingDestination &&
                          _notificationService.destinationStation?['name'] ==
                              station['name'];
                  return ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      if (isDestTracking) {
                        _notificationService.stopDestinationTracking();
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  '${AppLocalizations.current.tr("cancel_dest_done")} - ${station["name"]}'),
                              backgroundColor: AppColors.error,
                              behavior: SnackBarBehavior.floating),
                        );
                      } else {
                        // جيب أي باص نشط على هالخط
                        int? busId;
                        try {
                          final routeId = station['route_id'] ??
                              station['route']?['route_id'];
                          if (routeId != null) {
                            final api = ApiClient();
                            final busRes = await api.dio.get('/buses');
                            final buses =
                                List<Map<String, dynamic>>.from(busRes.data);
                            final activeBus = buses.firstWhere(
                              (b) =>
                                  b['route_id'] == routeId &&
                                  b['current_status'] == 'active',
                              orElse: () => buses.firstWhere(
                                  (b) => b['route_id'] == routeId,
                                  orElse: () => {}),
                            );
                            busId = activeBus['bus_id'];
                          }
                        } catch (_) {}

                        if (busId == null) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(AppLocalizations.current
                                      .tr('no_bus_on_route')),
                                  backgroundColor: AppColors.warning,
                                  behavior: SnackBarBehavior.floating),
                            );
                          }
                          return;
                        }

                        _notificationService.startDestinationTracking(
                          busId: busId,
                          destinationStation: {
                            'name': station['name'],
                            'lat': station['lat'],
                            'lng': station['lng']
                          },
                        );
                        setState(() {});
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    '📍     سيصلك تنبيه عندما يصل الباص  ${station['name']}'),
                                backgroundColor: const Color(0xFF00897B),
                                behavior: SnackBarBehavior.floating),
                          );
                        }
                      }
                    },
                    icon: Icon(
                        isDestTracking ? Icons.location_off : Icons.my_location,
                        size: 18),
                    label: Text(isDestTracking
                        ? AppLocalizations.current.tr('cancel_dest_tracking')
                        : AppLocalizations.current.tr('track_destination')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDestTracking
                          ? Colors.grey
                          : const Color(0xFF00897B),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.current.tr('the_map_title')),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isDarkMap ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => setState(() => _isDarkMap = !_isDarkMap),
          ),
          if (_notificationService.isTracking)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on,
                          color: Theme.of(context).cardColor, size: 14),
                      SizedBox(width: 4),
                      Text(
                        _notificationService.targetStation?['name'] ?? '',
                        style: TextStyle(
                            color: Theme.of(context).cardColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_notificationService.isTrackingDestination)
            Padding(
              padding: EdgeInsets.only(left: 8),
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    _notificationService.stopDestinationTracking();
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              AppLocalizations.current.tr('cancel_dest_done')),
                          backgroundColor: Colors.grey,
                          behavior: SnackBarBehavior.floating),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00897B),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(children: [
                      Icon(Icons.my_location,
                          color: Theme.of(context).cardColor, size: 14),
                      SizedBox(width: 4),
                      Text(
                          '📍 ${_notificationService.destinationStation?['name'] ?? ''}',
                          style: TextStyle(
                              color: Theme.of(context).cardColor,
                              fontSize: 11)),
                      const SizedBox(width: 4),
                      const Icon(Icons.close, color: Colors.white70, size: 12),
                    ]),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _currentPosition == null
              ? Center(
                  child:
                      Text(AppLocalizations.current.tr('cant_detect_location')))
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentPosition!,
                    initialZoom: 16,
                  ),
                  children: [
                    // خريطة OpenStreetMap
                    TileLayer(
                      urlTemplate: _isDarkMap
                          ? 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png'
                          : 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.bus_app',
                    ),
                    // موقع الراكب
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _currentPosition!,
                          width: 40,
                          height: 40,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Theme.of(context).cardColor, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  blurRadius: 10,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // المحطات
                    MarkerLayer(
                      markers: _stations
                          .map((station) {
                            final isTracking = _notificationService
                                    .isTracking &&
                                _notificationService.targetStation?['name'] ==
                                    station['name'];
                            final lat = _toDouble(station['lat']);
                            final lng = _toDouble(station['lng']);
                            if (lat == null || lng == null) {
                              return null;
                            }
                            return Marker(
                              point: LatLng(lat, lng),
                              width: 40,
                              height: 40,
                              child: GestureDetector(
                                onTap: () => _showStationPopup(station),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isTracking
                                        ? AppColors.success
                                        : AppColors.error,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Theme.of(context).cardColor,
                                        width: 2),
                                  ),
                                  child: Icon(
                                    Icons.directions_bus,
                                    color: Theme.of(context).cardColor,
                                    size: 20,
                                  ),
                                ),
                              ),
                            );
                          })
                          .whereType<Marker>()
                          .toList(),
                    ),

                    MarkerLayer(
                      markers: _buses
                          .map((bus) {
                            final lat = _toDouble(bus['lat']);
                            final lng = _toDouble(bus['lng']);
                            if (lat == null || lng == null) {
                              return null;
                            }

                            return Marker(
                              point: LatLng(lat, lng),
                              width: 86,
                              height: 66,
                              child: GestureDetector(
                                onTap: () => _showBusPopup(bus),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Theme.of(context).cardColor,
                                          width: 3,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary
                                                .withValues(alpha: 0.35),
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.directions_bus_filled,
                                        color: Theme.of(context).cardColor,
                                        size: 23,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      constraints:
                                          const BoxConstraints(maxWidth: 82),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).cardColor,
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.15),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        _formatBusValue(bus['plate_number']),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          })
                          .whereType<Marker>()
                          .toList(),
                    ),
                  ],
                ),

      // زر تحديد الموقع
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _getCurrentLocation();
          if (_currentPosition != null) {
            _mapController.move(_currentPosition!, 14);
          }
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }
}
