import '../../../../core/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/models/user_model.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;
  bool _hasSubscription = false;
  bool _loadingSubscription = true;
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user_data');
    if (userJson == null) return;
    final user = UserModel.fromJson(jsonDecode(userJson));
    setState(() => _user = user);
    await _checkSubscription(user.id);
  }


Future<void> _checkSubscription(int userId) async {
    try {
      final api = ApiClient();
      final response = await api.dio.get('/subscriptions/user/$userId');
      if (response.data != null && response.data['status'] == 'active') {
        final endDate = DateTime.parse(response.data['end_date']);
        final tripsUsed = response.data['trips_used'] ?? 0;
        final tripsLimit = response.data['trips_limit'] ?? 0;
        setState(() {
          _hasSubscription = endDate.isAfter(DateTime.now()) && tripsUsed < tripsLimit;
          _loadingSubscription = false;
        });
      } else {
        setState(() { _hasSubscription = false; _loadingSubscription = false; });
      }
    } catch (e) {
      setState(() { _hasSubscription = false; _loadingSubscription = false; });
    }
  }

  Future<void> _onQRDetected(String qrData) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    _controller.stop();

    try {
      final api = ApiClient();
      final response = await api.dio.post(
        '/buses/verify-qr',
        data: {
          'qr_data': qrData,
          'user_id': _user?.id,
        },
      );

      if (!mounted) return;
      _showSuccessDialog(response.data);
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog();
    }
  }
void _showSuccessDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70, height: 70,
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.check_circle_outline, color: AppColors.success, size: 40),
            ),
            SizedBox(height: 16),
            Text(AppLocalizations.current.tr('boarding_success'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            SizedBox(height: 12),

            // رقم الباص
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
              child: Column(children: [
                Text('🚌 ${data['plate_number'] ?? ''}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
                if (data['route_name'] != null)
                  Text('${AppLocalizations.current.tr("route_label")} ${data["route_name"]}', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ]),
            ),

            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (data['trips_remaining'] != null && data['trips_remaining'] <= 10)
                    ? AppColors.error.withOpacity(0.05)
                    : AppColors.success.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(children: [
                    Text(AppLocalizations.current.tr('trips_used'), style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    Text('${data['trips_used'] ?? 0}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ]),
                  Container(width: 1, height: 30, color: const Color(0xFFE5E7EB)),
                  Column(children: [
                    Text(AppLocalizations.current.tr('trips_total'), style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    Text('${data['trips_limit'] ?? 0}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ]),
                  Container(width: 1, height: 30, color: const Color(0xFFE5E7EB)),
                  Column(children: [
                    Text(AppLocalizations.current.tr('trips_remaining'), style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    Text('${data['trips_remaining'] ?? 0}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: (data['trips_remaining'] != null && data['trips_remaining'] <= 10) ? AppColors.error : AppColors.success)),
                  ]),
                ],
              ),
            ),

            if (data['trips_remaining'] != null && data['trips_remaining'] <= 10) ...[
              const SizedBox(height: 8),
              const Text('⚠️ رحلاتك أوشكت على الانتهاء  — جدد اشتراكك', style: TextStyle(color: AppColors.error, fontSize: 12)),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.pop(true);
              },
              child: Text(AppLocalizations.current.tr('done')),
            ),
          ),
        ],
      ),
    );
  }
  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                color: AppColors.error,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'فشل التحقق ❌',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'تأكد أنّك تملك اشتراك فعّال',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _isProcessing = false);
              _controller.start();
            },
            child: Text(AppLocalizations.current.tr('try_again')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.current.tr('close')),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Loading
    if (_loadingSubscription) {
      return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.current.tr('scan_qr')),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ما في اشتراك
    if (!_hasSubscription) {
      return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.current.tr('scan_qr')),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.qr_code_scanner,
                    size: 80, color: AppColors.primary.withOpacity(0.3)),
                const SizedBox(height: 16),
                const Text(
                  'يجب أن يكون لديك اشتراك فعّال',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'اشترك الآن لتتمكن من ركوب الباص',
                  style: TextStyle(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/subscription');
                  },
                  child: Text(AppLocalizations.current.tr('subscribe_now')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(AppLocalizations.current.tr('scan_qr_title')),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final barcode = capture.barcodes.firstOrNull;
              if (barcode?.rawValue != null) {
                _onQRDetected(barcode!.rawValue!);
              }
            },
          ),

          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.primary,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: _isProcessing
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text(
                      'وجّه الكاميرا نحو QR الباص',
                      style: TextStyle(
                        color: Theme.of(context).cardColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}