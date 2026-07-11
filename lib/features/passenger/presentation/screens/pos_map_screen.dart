import '../../../../core/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';

class POSMapScreen extends StatefulWidget {
  const POSMapScreen({super.key});

  @override
  State<POSMapScreen> createState() => _POSMapScreenState();
}

class _POSMapScreenState extends State<POSMapScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  List<Map<String, dynamic>> _posPoints = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _getCurrentLocation();
    await _loadPOSPoints();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() => _currentPosition = LatLng(position.latitude, position.longitude));
    } catch (e) {
      setState(() => _currentPosition = const LatLng(36.2021, 37.1343)); 
    }
  }

  Future<void> _loadPOSPoints() async {
    try {
      final api = ApiClient();
      final response = await api.dio.get('/pos/active');
      setState(() {
        _posPoints = List<Map<String, dynamic>>.from(response.data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showPOSDetails(Map<String, dynamic> pos) {
    final lat = pos['lat'];
    final lng = pos['lng'];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Row(textDirection: TextDirection.rtl, children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(color: const Color(0xFF00897B).withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.store, color: Color(0xFF00897B), size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(pos['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text(pos['owner_name'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              ])),
            ]),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
              child: Row(textDirection: TextDirection.rtl, children: [
                const Icon(Icons.phone, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Text(pos['phone'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ]),
            ),
            const SizedBox(height: 12),
            if (_currentPosition != null && lat != null && lng != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.success.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                child: Row(textDirection: TextDirection.rtl, children: [
                  const Icon(Icons.directions_walk, color: AppColors.success, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    '${(Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, lat, lng) / 1000).toStringAsFixed(1)} كم عنك',
                    style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600),
                  ),
                ]),
              ),
            SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final url = Uri.parse('tel:${pos['phone']}');
                    if (await canLaunchUrl(url)) await launchUrl(url);
                  },
                  icon: Icon(Icons.phone, size: 18),
                  label: Text(AppLocalizations.current.tr('call')),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                ),
              ),
              SizedBox(width: 10),
              if (lat != null && lng != null)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
                      if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
                    },
                    icon: Icon(Icons.directions, size: 18),
                    label: Text(AppLocalizations.current.tr('directions')),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00897B)),
                  ),
                ),
            ]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.current.tr('pos_stations')),
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _currentPosition == null
              ? Center(child: Text(AppLocalizations.current.tr('cant_detect_location')))
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(initialCenter: _currentPosition!, initialZoom: 13),
                  children: [
                    TileLayer(
  urlTemplate: 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
  userAgentPackageName: 'com.example.bus_app',
),
                    // موقع الراكب
                    MarkerLayer(markers: [
                      Marker(
                        point: _currentPosition!,
                        width: 40, height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue, shape: BoxShape.circle,
                            border: Border.all(color: Theme.of(context).cardColor, width: 3),
                            boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, spreadRadius: 5)],
                          ),
                        ),
                      ),
                    ]),
                    // نقاط البيع
                    MarkerLayer(
                      markers: _posPoints.map((pos) {
                        final lat = (pos['lat'] is int) ? (pos['lat'] as int).toDouble() : pos['lat'] as double;
                        final lng = (pos['lng'] is int) ? (pos['lng'] as int).toDouble() : pos['lng'] as double;
                        return Marker(
                          point: LatLng(lat, lng),
                          width: 44, height: 44,
                          child: GestureDetector(
                            onTap: () => _showPOSDetails(pos),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF00897B), shape: BoxShape.circle,
                                border: Border.all(color: Theme.of(context).cardColor, width: 2),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)],
                              ),
                              child: Icon(Icons.store, color: Theme.of(context).cardColor, size: 22),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _getCurrentLocation();
          if (_currentPosition != null) _mapController.move(_currentPosition!, 13);
        },
        backgroundColor: const Color(0xFF00897B),
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }
}