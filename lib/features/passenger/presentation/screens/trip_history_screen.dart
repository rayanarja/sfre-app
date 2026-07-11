import '../../../../core/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/models/user_model.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  List<Map<String, dynamic>> _trips = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user_data');
      if (userJson == null) return;
      final user = UserModel.fromJson(jsonDecode(userJson));

      final api = ApiClient();
      final response = await api.dio.get('/trip-history/user/${user.id}');
      setState(() {
        _trips = List<Map<String, dynamic>>.from(response.data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'الآن';
      if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
      if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
      if (diff.inDays == 1) return 'أمس';
      if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';

      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppLocalizations.current.tr('trip_history_title')),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trips.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _loadTrips,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _trips.length,
                    itemBuilder: (context, index) => _buildTripCard(_trips[index]),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: AppColors.primary.withOpacity(0.3)),
          SizedBox(height: 16),
          Text(AppLocalizations.current.tr('no_trips_yet'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          SizedBox(height: 8),
          Text(AppLocalizations.current.tr('scan_qr_to_appear'), style: TextStyle(color: AppColors.textHint, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    final busPlate = trip['bus']?['plate_number'] ?? '—';
    final routeName = trip['route_name'] ?? '';
    final boardedAt = trip['boarded_at'];
    final exitedAt = trip['exited_at'];
    final fromStation = trip['from_station'];
    final toStation = trip['to_station'];

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.directions_bus, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(busPlate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                      if (routeName.isNotEmpty)
                        Text(routeName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_formatDate(boardedAt), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  Text(_formatTime(boardedAt), style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            ],
          ),

          // المحطات
          if (fromStation != null || toStation != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  // من
                  Expanded(
                    child: Column(
                      children: [
                        Icon(Icons.my_location, size: 16, color: AppColors.primary),
                        SizedBox(height: 4),
                        Text(fromStation ?? '—', style: TextStyle(fontSize: 12, color: AppColors.textPrimary), textAlign: TextAlign.center),
                        Text(AppLocalizations.current.tr('boarding'), style: TextStyle(fontSize: 10, color: AppColors.textHint)),
                      ],
                    ),
                  ),

                  // سهم
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_back, size: 18, color: AppColors.textHint),
                  ),

                  // إلى
                  Expanded(
                    child: Column(
                      children: [
                        Icon(Icons.flag, size: 16, color: AppColors.success),
                        SizedBox(height: 4),
                        Text(toStation ?? '—', style: TextStyle(fontSize: 12, color: AppColors.textPrimary), textAlign: TextAlign.center),
                        Text(AppLocalizations.current.tr('exit'), style: TextStyle(fontSize: 10, color: AppColors.textHint)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (exitedAt == null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.circle, size: 8, color: AppColors.success),
                  SizedBox(width: 6),
                  Text(AppLocalizations.current.tr('trip_active'), style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}