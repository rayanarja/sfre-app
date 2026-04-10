import '../../../../core/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/models/user_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'dart:io';

class LostItemScreen extends StatefulWidget {
  const LostItemScreen({super.key});

  @override
  State<LostItemScreen> createState() => _LostItemScreenState();
}

class _LostItemScreenState extends State<LostItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  String? _selectedBusId;
  File? _selectedImage;
  List<Map<String, dynamic>> _buses = [];
  List<Map<String, dynamic>> _tripHistory = [];
  bool _isLoading = false;
  bool _loadingData = true;
  UserModel? _user;
  bool _isDriver = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user_data');
    if (userJson == null) return;
    final user = UserModel.fromJson(jsonDecode(userJson));
    setState(() {
      _user = user;
      _isDriver = user.isDriver;
    });

    try {
      final api = ApiClient();
      if (_isDriver) {
        final response = await api.dio.get('/buses');
        setState(() {
          _buses = List<Map<String, dynamic>>.from(response.data);
          _loadingData = false;
        });
      } else {
        final busRes = await api.dio.get('/buses');
        _buses = List<Map<String, dynamic>>.from(busRes.data);
        try {
          final tripRes = await api.dio.get('/trip-history/user/${user.id}');
          _tripHistory = List<Map<String, dynamic>>.from(tripRes.data);
        } catch (e) {}
        setState(() => _loadingData = false);
      }
    } catch (e) {
      setState(() => _loadingData = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.current.tr('choose_image_source'), textAlign: TextAlign.center),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
            icon: Icon(Icons.camera_alt),
            label: Text(AppLocalizations.current.tr('camera')),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
            icon: Icon(Icons.photo_library),
            label: Text(AppLocalizations.current.tr('gallery')),
          ),
        ],
      ),
    );
    if (source != null) {
      final picked = await picker.pickImage(source: source, imageQuality: 70, maxWidth: 1024);
      if (picked != null) {
        setState(() => _selectedImage = File(picked.path));
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBusId == null) {
      _showSnack(AppLocalizations.current.tr('please_select_bus'), AppColors.error);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final api = ApiClient();

      if (_selectedImage != null) {
        final formData = FormData.fromMap({
          'reporter_id': _user!.id,
          'bus_id': int.parse(_selectedBusId!),
          'reporter_type': _isDriver ? 'driver' : 'passenger',
          'description': _descriptionController.text.trim(),
          'found_location': _locationController.text.isEmpty ? '' : _locationController.text.trim(),
          'status': _isDriver ? 'found' : 'lost',
          'image': await MultipartFile.fromFile(_selectedImage!.path, filename: 'lost_item.jpg'),
        });
        await api.dio.post('/lost-items', data: formData);
      } else {
        await api.dio.post('/lost-items', data: {
          'reporter_id': _user!.id,
          'bus_id': int.parse(_selectedBusId!),
          'reporter_type': _isDriver ? 'driver' : 'passenger',
          'description': _descriptionController.text.trim(),
          'found_location': _locationController.text.isEmpty ? null : _locationController.text.trim(),
          'status': _isDriver ? 'found' : 'lost',
        });
      }

      if (!mounted) return;
      _showSnack(
        _isDriver ? '✅ تم الإبلاغ — سيتم إشعار الأدمن' : '✅ تم إرسال البلاغ — سنتواصل معك',
        AppColors.success,
      );
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      context.pop();
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack(AppLocalizations.current.tr('error'), AppColors.error);
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
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isDriver ? AppLocalizations.current.tr('report_found') : AppLocalizations.current.tr('report_lost')),
        backgroundColor: _isDriver ? AppColors.driverColor : AppColors.warning,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: _loadingData
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // رسالة توضيحية
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: (_isDriver ? AppColors.driverColor : AppColors.warning).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: (_isDriver ? AppColors.driverColor : AppColors.warning).withOpacity(0.3)),
                      ),
                      child: Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          Icon(_isDriver ? Icons.check_circle_outline : Icons.info_outline,
                              color: _isDriver ? AppColors.driverColor : AppColors.warning),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _isDriver
                                  ? 'لقيت غرض بالباص؟ بلّغ هون وسنشعر الأدمن'
                                  : 'نسيت غرض بالباص؟ بلّغنا وسنحاول إيجاده',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20),

                    // اختيار الباص
                    Text(
                      _isDriver ? 'الباص يلي لقيت فيه الغرض *' : 'الباص يلي كنت فيه *',
                      style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 15),
                    ),
                    SizedBox(height: 8),

                    if (!_isDriver && _tripHistory.isNotEmpty) ...[
                      Text(AppLocalizations.current.tr('choose_from_trips'), style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 8),
                      ..._tripHistory.take(3).map((trip) {
                        final busId = trip['bus']?['bus_id']?.toString();
                        final plate = trip['bus']?['plate_number'] ?? '—';
                        final route = trip['route_name'] ?? '';
                        final isSelected = _selectedBusId == busId;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedBusId = busId),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isSelected ? AppColors.primary : const Color(0xFFE5E7EB), width: isSelected ? 2 : 1),
                            ),
                            child: Row(
                              textDirection: TextDirection.rtl,
                              children: [
                                Icon(Icons.directions_bus, color: isSelected ? AppColors.primary : AppColors.textSecondary, size: 20),
                                const SizedBox(width: 8),
                                Text(plate, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? AppColors.primary : AppColors.textPrimary)),
                                if (route.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Text('($route)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                ],
                                const Spacer(),
                                if (isSelected) Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                              ],
                            ),
                          ),
                        );
                      }),
                      const Divider(),
                      Text(AppLocalizations.current.tr('or_choose_list'), style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      SizedBox(height: 8),
                    ],

                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          hint: Text(AppLocalizations.current.tr('select_bus')),
                          value: _selectedBusId,
                          items: _buses.map((bus) {
                            return DropdownMenuItem<String>(
                              value: bus['bus_id'].toString(),
                              child: Text('${AppLocalizations.current.tr("bus_label")} ${bus["plate_number"]}', textDirection: TextDirection.rtl),
                            );
                          }).toList(),
                          onChanged: (value) => setState(() => _selectedBusId = value),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // وصف الغرض
                    Text(
                      _isDriver ? 'وصف الغرض يلي لقيتو *' : 'وصف الغرض المفقود *',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 15),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      textDirection: TextDirection.rtl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: _isDriver ? 'e.g. brown leather wallet...' : 'e.g. small black bag...',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'الرجاء وصف الغرض';
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // المكان
                    Text(
                      _isDriver ? 'وين لقيتو بالباص؟ (اختياري)' : 'وين تقريباً نسيتو؟ (اختياري)',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 15),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _locationController,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        hintText: _isDriver ? 'e.g. under front seat...' : 'e.g. near back seat...',
                      ),
                    ),

                    SizedBox(height: 20),

                    // رفع صورة
                    Text(AppLocalizations.current.tr('item_photo'), style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 15)),
                    SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: double.infinity,
                        height: _selectedImage != null ? 200 : 100,
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _selectedImage != null ? AppColors.success : const Color(0xFFE5E7EB)),
                        ),
                        child: _selectedImage != null
                            ? Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(_selectedImage!, width: double.infinity, height: 200, fit: BoxFit.cover),
                                  ),
                                  Positioned(
                                    top: 8, left: 8,
                                    child: GestureDetector(
                                      onTap: () => setState(() => _selectedImage = null),
                                      child: Container(
                                        padding: EdgeInsets.all(4),
                                        decoration: BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                                        child: Icon(Icons.close, color: Theme.of(context).cardColor, size: 16),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_outlined, size: 32, color: AppColors.textHint),
                                  SizedBox(height: 8),
                                  Text(AppLocalizations.current.tr('tap_add_photo'), style: TextStyle(color: AppColors.textHint, fontSize: 13)),
                                ],
                              ),
                      ),
                    ),

                    SizedBox(height: 32),

                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isDriver ? AppColors.driverColor : AppColors.warning,
                      ),
                      child: _isLoading
                          ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Theme.of(context).cardColor, strokeWidth: 2))
                          : Text(_isDriver ? AppLocalizations.current.tr('report_item') : AppLocalizations.current.tr('send_report_btn')),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}