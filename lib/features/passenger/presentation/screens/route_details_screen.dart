import '../../../../core/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/notification_service.dart';

class RouteDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> route;
  const RouteDetailsScreen({super.key, required this.route});

  @override
  State<RouteDetailsScreen> createState() => _RouteDetailsScreenState();
}

class _RouteDetailsScreenState extends State<RouteDetailsScreen> {
  final NotificationService _notificationService = NotificationService();
  Position? _currentPosition;
  Map<String, dynamic>? _nearestStation;
  bool _loadingLocation = true;

  @override
  void initState() {
    super.initState();
    _findNearestStation();
  }

  Future<void> _findNearestStation() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _loadingLocation = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() => _currentPosition = position);

      final stations = (widget.route['stations'] as List?) ?? [];
      Map<String, dynamic>? nearest;
      double minDistance = double.infinity;

      for (final station in stations) {
        if (station['latitude'] == null || station['longitude'] == null) continue;

        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          station['latitude'],
          station['longitude'],
        );

        if (distance < minDistance) {
          minDistance = distance;
          nearest = {...station, 'distance': minDistance};
        }
      }

      setState(() {
        _nearestStation = nearest;
        _loadingLocation = false;
      });
    } catch (e) {
      setState(() => _loadingLocation = false);
    }
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.toInt()} متر';
    return '${(meters / 1000).toStringAsFixed(1)} كم';
  }

  @override
  Widget build(BuildContext context) {
    final stations = (widget.route['stations'] as List?) ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.route['route_name'] ?? AppLocalizations.current.tr('route_details')),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [

            // أقرب محطة
            if (_loadingLocation)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text(AppLocalizations.current.tr('detecting_your_loc')),
                  ],
                ),
              )
            else if (_nearestStation != null) ...[
              const Text(
                '📍 أقرب موقف لك',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      textDirection: TextDirection.rtl,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDistance(_nearestStation!['distance']),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _nearestStation!['name'] ?? '—',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // زر تنبيهني للمحطة الأقرب
                    if (_nearestStation!['latitude'] != null)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final isTracking = _notificationService.isTracking &&
                                _notificationService.targetStation?['name'] ==
                                    _nearestStation!['name'];

                            if (isTracking) {
                              _notificationService.stopTracking();
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(AppLocalizations.current.tr('alert_cancelled')),
                                  backgroundColor: AppColors.error,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            } else {
                              if (_notificationService.isTracking) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'أنت تتابع محطة أخرى — ألغِها أولاً'),
                                    backgroundColor: AppColors.warning,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }
                              _notificationService.startTracking({
                                'name': _nearestStation!['name'],
                                'latitude': _nearestStation!['latitude'],
                                'longitude': _nearestStation!['longitude'],
                              });
                              setState(() {});
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      '✅   سيصلك تنبيه عندما  تقترب من ${_nearestStation!['name']}'),
                                  backgroundColor: AppColors.success,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          icon: Icon(
                            _notificationService.isTracking &&
                                    _notificationService.targetStation?['name'] ==
                                        _nearestStation!['name']
                                ? Icons.notifications_active
                                : Icons.notifications_outlined,
                            size: 18,
                          ),
                          label: Text(
                            _notificationService.isTracking &&
                                    _notificationService.targetStation?['name'] ==
                                        _nearestStation!['name']
                                ? 'جاري التتبع — اضغط للإلغاء'
                                : 'تنبيهني عند الوصول للموقف',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _notificationService.isTracking &&
                                    _notificationService.targetStation?['name'] ==
                                        _nearestStation!['name']
                                ? AppColors.success
                                : AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // كل المحطات
            const Text(
              '🗺️ محطات الخط',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            if (stations.isEmpty)
              const Center(
                child: Text(
                  ' لا يوجد محطات لهذا الخط',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),

            ...stations.map((station) {
              final isNearest = _nearestStation != null &&
                  _nearestStation!['name'] == station['name'];

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isNearest
                      ? AppColors.primary.withOpacity(0.05)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isNearest
                        ? AppColors.primary.withOpacity(0.3)
                        : const Color(0xFFE5E7EB),
                    width: isNearest ? 2 : 1,
                  ),
                ),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Icon(
                      isNearest
                          ? Icons.location_on
                          : Icons.location_on_outlined,
                      color: isNearest
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        station['name'] ?? '—',
                        style: TextStyle(
                          fontWeight: isNearest
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isNearest
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    if (isNearest)
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'أقرب موقف',
                          style: TextStyle(
                            color: Theme.of(context).cardColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}